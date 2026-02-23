# frozen_string_literal: true

class CustomersController < ApplicationController
  before_action :set_customer, only: %i[show edit update destroy download_invoice download_invoices_by_center download_statement]

  def index
    respond_to do |format|
      format.html do
        # 会社一覧を取得（Internal Adminは全社、Company Adminは自社のみ）
        if current_user&.internal_admin?
          @companies = Company.active.order(:code)
        else
          @companies = [current_company].compact
        end

        # 選択された会社（パラメータから、またはデフォルトで最初の会社）
        selected_company_id = params[:company_id]&.to_i
        if selected_company_id && @companies.map(&:id).include?(selected_company_id)
          @selected_company = Company.find(selected_company_id)
        else
          @selected_company = @companies.first
        end

        # タブで請求先センターと受注センターを切り替え
        @show_billing_centers = params[:type] == 'billing_centers'
        
        # 選択された会社のセンターを取得（無効なものも含む）
        if @selected_company
          customers_scope = policy_scope(Customer)
            .for_company(@selected_company)
          
          if @show_billing_centers
            customers_scope = customers_scope.billing_centers
          else
            customers_scope = customers_scope.receiving_centers
          end
          
          customers_scope = customers_scope.reorder(sort_order)
        else
          customers_scope = policy_scope(Customer).none
        end

        @pagy, @customers = pagy(customers_scope)
      end
      format.json do
        company_id = params[:company_id]&.to_i
        billing_centers_only = params[:billing_centers_only] == 'true'
        
        if company_id
          company = Company.find(company_id)
          customers = policy_scope(Customer)
            .for_company(company)
          
          customers = customers.billing_centers if billing_centers_only
          customers = customers.active.order(:center_code)
          
          render json: customers.map { |c| { id: c.id, display_name: c.display_name } }
        else
          render json: []
        end
      end
    end
  end

  def show
    authorize @customer
    
    # 請求先センターの場合、紐づく受注センターごとのOrderを取得
    if @customer.is_billing_center?
      @receiving_centers_with_orders = @customer.customers
        .includes(orders: [:ordered_by_user, :order_lines])
        .order(:center_code)
        .map do |receiving_center|
          orders = receiving_center.orders.includes(:order_approval_request).order(order_date: :desc, created_at: :desc).limit(10)
          {
            receiving_center: receiving_center,
            orders: orders,
            total_orders_count: receiving_center.orders.count,
            total_amount: receiving_center.orders.sum(:total_amount)
          }
        end
    end
  end

  def new
    @customer = Customer.new
    @companies = Company.active.order(:name) if current_user&.internal_admin?
    load_billing_centers
    authorize @customer
  end

  def edit
    @companies = Company.active.order(:name) if current_user&.internal_admin?
    load_billing_centers
    authorize @customer
  end

  def create
    customer_params_hash = customer_params.to_h
    # 請求先として設定する場合は、billing_center_idをnilにする
    if customer_params_hash[:is_billing_center] == '1' || customer_params_hash[:is_billing_center] == true || customer_params_hash[:is_billing_center] == 'true'
      customer_params_hash[:billing_center_id] = nil
      customer_params_hash[:is_billing_center] = true
    else
      customer_params_hash[:is_billing_center] = false
      # 受注センターの場合は、請求先センターが必須
      if customer_params_hash[:billing_center_id].blank?
        @customer = Customer.new(customer_params_hash)
        @companies = Company.active.order(:name) if current_user&.internal_admin?
        load_billing_centers
        authorize @customer
        @customer.errors.add(:billing_center_id, "must be present for receiving centers")
        render :new, status: :unprocessable_entity
        return
      end
    end

    @customer = Customer.new(customer_params_hash)
    @companies = Company.active.order(:name) if current_user&.internal_admin?
    load_billing_centers
    authorize @customer

    if @customer.save
      redirect_to @customer, notice: t("customers.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @customer
    load_billing_centers

    customer_params_hash = customer_params.to_h
    # 請求先として設定する場合は、billing_center_idをnilにする
    if customer_params_hash[:is_billing_center] == '1' || customer_params_hash[:is_billing_center] == true || customer_params_hash[:is_billing_center] == 'true'
      customer_params_hash[:billing_center_id] = nil
      customer_params_hash[:is_billing_center] = true
    else
      customer_params_hash[:is_billing_center] = false
      # 受注センターの場合は、請求先センターが必須
      if customer_params_hash[:billing_center_id].blank?
        @customer.errors.add(:billing_center_id, "must be present for receiving centers")
        render :edit, status: :unprocessable_entity
        return
      end
    end

    if @customer.update(customer_params_hash)
      redirect_to @customer, notice: t("customers.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @customer

    if @customer.update(is_active: false)
      redirect_to customers_path, notice: t("customers.deactivated")
    else
      redirect_to @customer, alert: t("customers.deactivate_failed")
    end
  end

  def download_invoice
    authorize @customer
    
    # 請求先センターのみ請求書をダウンロード可能
    unless @customer.is_billing_center?
      redirect_to @customer, alert: t("customers.invoice.only_billing_center")
      return
    end

    year = params[:year]&.to_i || Date.current.year
    month = params[:month]&.to_i || Date.current.month

    generator = InvoiceGenerator.new(@customer, year, month)
    pdf = generator.generate

    if pdf.nil?
      redirect_to @customer, alert: t("customers.invoice.no_orders")
      return
    end

    filename = "請求書_#{@customer.center_code}_#{year}年#{month}月.pdf"
    send_data pdf.render, filename: filename, type: 'application/pdf', disposition: 'attachment'
  end

  def download_invoices_by_center
    authorize @customer, :download_invoices_by_center?

    unless @customer.is_billing_center?
      redirect_to @customer, alert: t("customers.invoice.only_billing_center")
      return
    end

    year = params[:year]&.to_i || Date.current.year
    month = params[:month]&.to_i || Date.current.month

    receiving_centers = @customer.customers.active.order(:center_code)
    if receiving_centers.empty?
      redirect_to @customer, alert: t("customers.invoice_by_center.no_receiving_centers")
      return
    end

    require "zip"
    count = 0
    buffer = Zip::OutputStream.write_buffer do |zio|
      receiving_centers.each do |rc|
        generator = InvoiceGenerator.new(@customer, year, month, receiving_center: rc)
        pdf = generator.generate
        next if pdf.nil?

        entry_name = "請求書_#{rc.center_code}_#{year}年#{month}月.pdf"
        zio.put_next_entry(entry_name)
        zio.write(pdf.render)
        count += 1
      end
      # 請求先センター自身に発注がある場合も1枚出す
      generator_self = InvoiceGenerator.new(@customer, year, month, receiving_center: @customer)
      pdf_self = generator_self.generate
      if pdf_self
        entry_name = "請求書_#{@customer.center_code}_#{year}年#{month}月.pdf"
        zio.put_next_entry(entry_name)
        zio.write(pdf_self.render)
        count += 1
      end
    end

    if count.zero?
      redirect_to @customer, alert: t("customers.invoice.no_orders")
      return
    end

    zip_filename = "請求書_センター別_#{@customer.center_name}_#{year}年#{month}月.zip"
    send_data buffer.string, filename: zip_filename, type: "application/zip", disposition: "attachment"
  end

  def download_statement
    authorize @customer, :download_statement?

    year = params[:year]&.to_i || Date.current.year
    month = params[:month]&.to_i || Date.current.month

    generator = StatementGenerator.new(@customer, year, month)
    pdf = generator.generate

    if pdf.nil?
      redirect_to @customer, alert: t("customers.statement.no_orders")
      return
    end

    filename = "明細書_#{@customer.center_code}_#{year}年#{month}月.pdf"
    send_data pdf.render, filename: filename, type: 'application/pdf', disposition: 'attachment'
  end

  def download_invoices_bulk
    authorize Customer, :download_invoices_bulk?

    company_id = params[:company_id]&.to_i
    year = params[:year]&.to_i || Date.current.year
    month = params[:month]&.to_i || Date.current.month

    company = Company.find_by(id: company_id)
    unless company
      redirect_to customers_path, alert: t("customers.invoice_bulk.invalid_company")
      return
    end

    # Internal Adminのみ全社指定可（会社は上で取得済み）
    unless current_user&.internal_admin?
      redirect_to customers_path, alert: t("pundit.not_authorized")
      return
    end

    billing_centers = company.customers.billing_centers.active.order(:center_code)
    if billing_centers.empty?
      redirect_to customers_path(company_id: company.id, type: "billing_centers"), alert: t("customers.invoice_bulk.no_billing_centers")
      return
    end

    require "zip"
    count = 0
    buffer = Zip::OutputStream.write_buffer do |zio|
      billing_centers.each do |billing_center|
        generator = InvoiceGenerator.new(billing_center, year, month)
        pdf = generator.generate
        next if pdf.nil?

        entry_name = "請求書_#{billing_center.center_code}_#{year}年#{month}月.pdf"
        zio.put_next_entry(entry_name)
        zio.write(pdf.render)
        count += 1
      end
    end

    if count.zero?
      redirect_to customers_path(company_id: company.id, type: "billing_centers"), alert: t("customers.invoice_bulk.no_orders")
      return
    end

    zip_filename = "請求書_#{company.name}_#{year}年#{month}月.zip"
    send_data buffer.string, filename: zip_filename, type: "application/zip", disposition: "attachment"
  end

  def import
    authorize Customer, :import?
    
    if request.get?
      @companies = Company.active.order(:name)
      render :import
    elsif request.post?
      @companies = Company.active.order(:name)
      company_id = params[:company_id]&.to_i
      csv_file = params[:csv_file]

      unless company_id.present? && csv_file.present?
        flash.now[:alert] = t("customers.import.missing_params")
        render :import, status: :unprocessable_entity
        return
      end

      company = Company.find_by(id: company_id)
      unless company
        flash.now[:alert] = t("customers.import.invalid_company")
        render :import, status: :unprocessable_entity
        return
      end

      result = import_customers_from_csv(csv_file, company)
      
      if result[:success]
        redirect_to customers_path(company_id: company.id), 
          notice: t("customers.import.success", 
            created: result[:created], 
            updated: result[:updated], 
            errors: result[:errors])
      else
        flash.now[:alert] = t("customers.import.failed", errors: result[:errors])
        @import_errors = result[:import_errors]
        render :import, status: :unprocessable_entity
      end
    end
  end

  def import_assignments
    authorize Customer, :import?

    if request.get?
      load_companies_for_import_assignments
      render :import_assignments
      return
    end

    company_id = params[:company_id]&.to_i
    csv_file = params[:csv_file]
    unless company_id.present? && csv_file.present?
      load_companies_for_import_assignments
      flash.now[:alert] = t("customers.import_assignments.missing_params")
      render :import_assignments, status: :unprocessable_entity
      return
    end

    company = Company.find_by(id: company_id)
    unless company && (current_user.internal_admin? || current_company&.id == company.id)
      load_companies_for_import_assignments
      flash.now[:alert] = t("customers.import_assignments.invalid_company")
      render :import_assignments, status: :unprocessable_entity
      return
    end

    importer = CenterAssignmentCsvImporter.new(company)
    success = importer.run(csv_file.read)
    if success
      redirect_to customers_path(company_id: company.id, type: "billing_centers"),
        notice: t("customers.import_assignments.success", centers: importer.updated_centers, members: importer.updated_members)
    else
      load_companies_for_import_assignments
      @import_errors = importer.errors
      flash.now[:alert] = importer.errors.first(3).join(" ")
      render :import_assignments, status: :unprocessable_entity
    end
  end

  private

  def load_companies_for_import_assignments
    if current_user.internal_admin?
      @companies = Company.active.order(:code)
    else
      @companies = [current_company].compact
    end
    @selected_company_id = params[:company_id]&.to_i
  end

  SORTABLE_COLUMNS = %w[center_code center_name prefecture city is_active].freeze

  def sort_column
    col = params[:sort].to_s
    SORTABLE_COLUMNS.include?(col) ? col : "center_code"
  end

  def sort_direction
    %w[asc desc].include?(params[:direction].to_s) ? params[:direction].to_s : "asc"
  end

  def sort_order
    # ORDER BY 用の文字列（sort_column / sort_direction はホワイトリスト済み）
    "#{sort_column} #{sort_direction.upcase}"
  end

  def set_customer
    @customer = policy_scope(Customer).find(params[:id])
  end

  def load_billing_centers
    # 編集対象のCustomerの会社、または新規作成時のcurrent_companyの請求先センターを取得
    target_company = @customer&.company || current_company
    if target_company
      @billing_centers = Customer
        .for_company(target_company)
        .billing_centers
        .active
        .order(:center_code)
        .map { |c| [c.display_name, c.id] }
      # 承認者候補（承認者・会社管理者・内部管理者ロール）
      @approver_candidates = UserProfile
        .for_company(target_company)
        .where(role: %i[approver company_admin internal_admin])
        .active_members
        .includes(:user)
        .order(:name)
        .map { |p| ["#{p.name} (#{p.user&.email})", p.id] }
    else
      @billing_centers = []
      @approver_candidates = []
    end
  end

  def customer_params
    params.require(:customer).permit(
      :company_id, :billing_center_id, :is_billing_center, :center_code, :center_name, :postal_code, :prefecture,
      :city, :address1, :address2, :is_active, :approver_user_profile_id
    )
  end

  def import_customers_from_csv(csv_file, company)
    require "csv"
    
    created = 0
    updated = 0
    errors = []
    import_errors = []

    begin
      csv_content = csv_file.read.force_encoding("UTF-8")
      csv = CSV.parse(csv_content, headers: true, encoding: "UTF-8")
      
      if csv.headers.nil? || csv.headers.empty?
        return { success: false, errors: [t("customers.import.invalid_format")], import_errors: [] }
      end

      # 必須カラムの確認
      required_headers = ["center_code", "center_name"]
      missing_headers = required_headers - csv.headers.map(&:downcase)
      if missing_headers.any?
        return { 
          success: false, 
          errors: [t("customers.import.missing_headers", headers: missing_headers.join(", "))], 
          import_errors: [] 
        }
      end

      ActiveRecord::Base.transaction do
        csv.each_with_index do |row, index|
          row_number = index + 2 # ヘッダー行を考慮して+2
          
          begin
            center_code = row["center_code"]&.strip
            center_name = row["center_name"]&.strip
            
            if center_code.blank? || center_name.blank?
              import_errors << { row: row_number, message: t("customers.import.required_fields_missing") }
              next
            end

            customer = Customer.find_or_initialize_by(
              company: company,
              center_code: center_code
            )

            customer.assign_attributes(
              center_name: center_name,
              postal_code: row["postal_code"]&.strip,
              prefecture: row["prefecture"]&.strip,
              city: row["city"]&.strip,
              address1: row["address1"]&.strip,
              address2: row["address2"]&.strip,
              is_active: row["is_active"]&.strip&.downcase == "true" || row["is_active"]&.strip == "1" || row["is_active"].blank?
            )

            if customer.save
              if customer.persisted_before_last_save?
                updated += 1
              else
                created += 1
              end
            else
              import_errors << { 
                row: row_number, 
                message: customer.errors.full_messages.join(", "),
                center_code: center_code
              }
            end
          rescue => e
            import_errors << { row: row_number, message: e.message }
          end
        end
      end

      { 
        success: import_errors.empty?, 
        created: created, 
        updated: updated, 
        errors: import_errors.size,
        import_errors: import_errors
      }
    rescue CSV::MalformedCSVError => e
      { success: false, errors: [t("customers.import.csv_parse_error", error: e.message)], import_errors: [] }
    rescue => e
      { success: false, errors: [t("customers.import.unknown_error", error: e.message)], import_errors: [] }
    end
  end
end
