# frozen_string_literal: true

class CustomersController < ApplicationController
  before_action :set_customer, only: %i[show edit update destroy]

  def index
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

    # 選択された会社のセンターを取得（無効なものも含む）
    if @selected_company
      customers_scope = policy_scope(Customer)
        .for_company(@selected_company)
        .order(:center_code)
    else
      customers_scope = policy_scope(Customer).none
    end

    @pagy, @customers = pagy(customers_scope)
  end

  def show
    authorize @customer
  end

  def new
    @customer = Customer.new
    @companies = Company.active.order(:name) if current_user&.internal_admin?
    authorize @customer
  end

  def edit
    @companies = Company.active.order(:name) if current_user&.internal_admin?
    authorize @customer
  end

  def create
    @customer = Customer.new(customer_params)
    @companies = Company.active.order(:name) if current_user&.internal_admin?
    authorize @customer

    if @customer.save
      redirect_to @customer, notice: t("customers.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @customer

    if @customer.update(customer_params)
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

  private

  def set_customer
    @customer = policy_scope(Customer).find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(
      :company_id, :center_code, :center_name, :postal_code, :prefecture,
      :city, :address1, :address2, :is_active
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
