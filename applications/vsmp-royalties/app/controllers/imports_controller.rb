class ImportsController < ApplicationController
  before_action :set_import, only: %i[ show edit update destroy ]

  # GET /imports or /imports.json
  def index
    @imports = Import.order(created_at: :desc)
  end

  # GET /imports/1 or /imports/1.json
  def show
  end

  # GET /imports/new
  def new
    @import = Import.new
  end

  # GET /imports/1/edit
  def edit
  end

  # POST /imports or /imports.json
  def create
    @import = Import.new(import_params)

    # Auto-populate original_file_name from uploaded file
    if @import.csv_file.attached?
      @import.original_file_name = @import.csv_file.filename.to_s
    end

    respond_to do |format|
      if @import.save
        format.html { redirect_to @import, notice: "Import started! Processing CSV file..." }
        format.json { render :show, status: :created, location: @import }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @import.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /imports/1 or /imports/1.json
  def update
    respond_to do |format|
      if @import.update(import_params)
        format.html { redirect_to @import, notice: "Import was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @import }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @import.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /imports/1 or /imports/1.json
  def destroy
    respond_to do |format|
      if @import.destroy
        format.html { redirect_to imports_path, notice: "Import was successfully rolled back.", status: :see_other }
        format.json { head :no_content }
      else
        format.html { redirect_to imports_path, alert: @import.errors.full_messages.to_sentence, status: :see_other }
        format.json { render json: @import.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_import
      @import = Import.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def import_params
      params.expect(import: [ :fiscal_year, :fiscal_quarter, :csv_file ])
    end
end
