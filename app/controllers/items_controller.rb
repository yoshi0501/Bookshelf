# frozen_string_literal: true

class ItemsController < ApplicationController
  before_action :set_item, only: %i[show edit update destroy]

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

    # 選択された会社の商品を取得（無効なものも含む）
    if @selected_company
      items_scope = policy_scope(Item)
        .for_company(@selected_company)
        .ordered_by_code
    else
      items_scope = policy_scope(Item).none
    end

    @pagy, @items = pagy(items_scope)
  end

  def show
    authorize @item
  end

  def new
    @item = Item.new
    @companies = Company.active.order(:name) # 内部管理者が会社を選択
    authorize @item
  end

  def edit
    @companies = Company.active.order(:name) # 内部管理者が会社を選択
    authorize @item
  end

  def create
    @item = Item.new(item_params)
    @companies = Company.active.order(:name)
    authorize @item

    if @item.save
      # 内部管理者のみが商品の表示会社を設定可能
      update_visible_companies(@item, params[:item][:visible_company_ids])
      redirect_to @item, notice: t("items.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @companies = Company.active.order(:name)
    authorize @item

    if params.dig(:item, :remove_image) == "1"
      @item.image.purge
    end
    if @item.update(item_params)
      # 内部管理者のみが商品の表示会社を設定可能
      update_visible_companies(@item, params[:item][:visible_company_ids])
      redirect_to @item, notice: t("items.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @item

    if @item.update(is_active: false)
      redirect_to items_path, notice: t("items.deactivated")
    else
      redirect_to @item, alert: t("items.deactivate_failed")
    end
  end

  def import
    authorize Item, :import?
    
    if request.get?
      @companies = Company.active.order(:name)
      render :import
    elsif request.post?
      @companies = Company.active.order(:name)
      csv_file = params[:csv_file]

      unless csv_file.present?
        flash.now[:alert] = t("items.import.missing_params")
        render :import, status: :unprocessable_entity
        return
      end

      result = import_items_from_csv(csv_file)
      
      if result[:success]
        redirect_to items_path, 
          notice: t("items.import.success", 
            created: result[:created], 
            updated: result[:updated], 
            errors: result[:errors])
      else
        flash.now[:alert] = t("items.import.failed", errors: result[:errors])
        @import_errors = result[:import_errors]
        render :import, status: :unprocessable_entity
      end
    end
  end

  private

  def set_item
    @item = policy_scope(Item).find(params[:id])
  end

  def item_params
    params.require(:item).permit(
      :company_id, :item_code, :name, :unit_price, :co2_per_unit,
      :cost_price, :shipping_cost, :is_active, :image, :remove_image
    )
  end

  def update_visible_companies(item, company_ids)
    return unless current_user&.internal_admin?
    return unless company_ids

    # 既存の関連を削除
    item.item_companies.destroy_all

    # 新しい関連を作成（空の配列の場合は何もしない）
    company_ids.reject(&:blank?).each do |company_id|
      company = Company.find_by(id: company_id)
      next unless company
      # 販売元会社は自動的に選択されるので、販売元以外のみ追加
      next if company.id == item.company_id

      ItemCompany.create!(item: item, company: company)
    end
  end

  def import_items_from_csv(csv_file)
    require "csv"
    
    created = 0
    updated = 0
    errors = []
    import_errors = []

    begin
      csv_content = csv_file.read.force_encoding("UTF-8")
      csv = CSV.parse(csv_content, headers: true, encoding: "UTF-8")
      
      if csv.headers.nil? || csv.headers.empty?
        return { success: false, errors: [t("items.import.invalid_format")], import_errors: [] }
      end

      # 必須カラムの確認
      required_headers = ["item_code", "name", "unit_price", "company_code"]
      missing_headers = required_headers - csv.headers.map(&:downcase)
      if missing_headers.any?
        return { 
          success: false, 
          errors: [t("items.import.missing_headers", headers: missing_headers.join(", "))], 
          import_errors: [] 
        }
      end

      ActiveRecord::Base.transaction do
        csv.each_with_index do |row, index|
          row_number = index + 2 # ヘッダー行を考慮して+2
          
          begin
            item_code = row["item_code"]&.strip
            name = row["name"]&.strip
            unit_price_str = row["unit_price"]&.strip
            company_code = row["company_code"]&.strip
            co2_per_unit_str = row["co2_per_unit"]&.strip
            is_active_str = row["is_active"]&.strip
            visible_company_codes_str = row["visible_company_codes"]&.strip
            
            # 必須フィールドのチェック
            if item_code.blank? || name.blank? || unit_price_str.blank? || company_code.blank?
              import_errors << { 
                row: row_number, 
                message: t("items.import.required_fields_missing"),
                item_code: item_code || "-"
              }
              next
            end

            # 会社の検索
            company = Company.find_by(code: company_code)
            unless company
              import_errors << { 
                row: row_number, 
                message: t("items.import.company_not_found", code: company_code),
                item_code: item_code
              }
              next
            end

            # 単価の変換
            unit_price = unit_price_str.to_f
            if unit_price <= 0
              import_errors << { 
                row: row_number, 
                message: t("items.import.invalid_unit_price"),
                item_code: item_code
              }
              next
            end

            # CO2/単位の変換（オプション）
            co2_per_unit = co2_per_unit_str.present? ? co2_per_unit_str.to_f : nil
            if co2_per_unit.present? && co2_per_unit < 0
              import_errors << { 
                row: row_number, 
                message: t("items.import.invalid_co2"),
                item_code: item_code
              }
              next
            end

            # 有効/無効の変換
            is_active = is_active_str.blank? || 
                       is_active_str.downcase == "true" || 
                       is_active_str == "1"

            # 商品の検索または作成
            item = Item.find_or_initialize_by(
              company: company,
              item_code: item_code
            )

            cost_price_str = row["cost_price"]&.strip
            shipping_cost_str = row["shipping_cost"]&.strip
            cost_price = cost_price_str.present? ? cost_price_str.to_f : nil
            shipping_cost = shipping_cost_str.present? ? shipping_cost_str.to_f : nil

            item.assign_attributes(
              name: name,
              unit_price: unit_price,
              co2_per_unit: co2_per_unit,
              cost_price: cost_price,
              shipping_cost: shipping_cost,
              is_active: is_active
            )

            if item.save
              # 販売先会社の設定（オプション）
              if visible_company_codes_str.present?
                visible_company_codes = visible_company_codes_str.split(",").map(&:strip)
                # 既存の関連を削除
                item.item_companies.destroy_all
                
                # 販売元会社は自動的に追加
                ItemCompany.find_or_create_by(item: item, company: company)
                
                # 販売先会社を追加
                visible_company_codes.each do |code|
                  visible_company = Company.find_by(code: code)
                  next unless visible_company
                  # 販売元会社は既に追加済みなのでスキップ
                  next if visible_company.id == company.id
                  
                  ItemCompany.find_or_create_by(item: item, company: visible_company)
                end
              end

              if item.persisted_before_last_save?
                updated += 1
              else
                created += 1
              end
            else
              import_errors << { 
                row: row_number, 
                message: item.errors.full_messages.join(", "),
                item_code: item_code
              }
            end
          rescue => e
            import_errors << { 
              row: row_number, 
              message: e.message,
              item_code: row["item_code"]&.strip || "-"
            }
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
      { success: false, errors: [t("items.import.csv_parse_error", error: e.message)], import_errors: [] }
    rescue => e
      { success: false, errors: [t("items.import.unknown_error", error: e.message)], import_errors: [] }
    end
  end
end
