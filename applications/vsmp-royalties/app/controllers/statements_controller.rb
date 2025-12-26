class StatementsController < ApplicationController
  before_action :set_statement, only: %i[ show edit update destroy mark_invoiced download_export resolve_conflict ]
  before_action :prevent_edit_if_invoiced, only: %i[ edit update destroy ]

  # GET /statements or /statements.json
  def index
    @statements = Statement.all
  end

  # GET /statements/1 or /statements/1.json
  def show
  end

  # GET /statements/new
  def new
    @statement = Statement.new
  end

  # GET /statements/1/edit
  def edit
  end

  # POST /statements or /statements.json
  def create
    @statement = Statement.new(statement_params)

    # Store writer_ids from form
    @statement.writer_ids = params[:statement][:writer_ids].reject(&:blank?) if params[:statement][:writer_ids]

    respond_to do |format|
      if @statement.save
        format.html { redirect_to @statement, notice: "Statement created! Populating royalties..." }
        format.json { render :show, status: :created, location: @statement }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @statement.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /statements/1 or /statements/1.json
  def update
    respond_to do |format|
      if @statement.update(statement_params)
        format.html { redirect_to @statement, notice: "Statement was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @statement }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @statement.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /statements/1 or /statements/1.json
  def destroy
    @statement.destroy!

    respond_to do |format|
      format.html { redirect_to statements_path, notice: "Statement was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # POST /statements/:id/mark_invoiced
  def mark_invoiced
    if @statement.has_conflicts?
      redirect_to @statement, alert: "Cannot mark as invoiced: statement has unresolved conflicts"
      return
    end

    @statement.update!(invoiced: true, invoiced_at: Time.current)
    redirect_to @statement, notice: "Statement marked as invoiced and locked"
  end

  # POST /statements/:id/download_export
  def download_export
    unless @statement.export_csv.attached?
      redirect_to @statement, alert: "Export not yet generated"
      return
    end

    redirect_to rails_blob_path(@statement.export_csv, disposition: "attachment")
  end

  # POST /statements/:id/resolve_conflict
  def resolve_conflict
    conflict = @statement.statement_conflicts.find(params[:conflict_id])
    conflict.update!(resolved: true)
    redirect_to @statement, notice: "Conflict marked as resolved"
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_statement
      @statement = Statement.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def statement_params
      params.expect(statement: [ :fiscal_year, :fiscal_quarter, :invoiced, :invoiced_at, writer_ids: [] ])
    end

    def prevent_edit_if_invoiced
      if @statement.invoiced?
        redirect_to @statement, alert: "Cannot edit invoiced statement"
      end
    end
end
