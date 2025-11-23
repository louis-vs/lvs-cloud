class RightTypesController < ApplicationController
  before_action :set_right_type, only: %i[ show edit update destroy ]

  # GET /right_types or /right_types.json
  def index
    @right_types = RightType.all
  end

  # GET /right_types/1 or /right_types/1.json
  def show
  end

  # GET /right_types/new
  def new
    @right_type = RightType.new
  end

  # GET /right_types/1/edit
  def edit
  end

  # POST /right_types or /right_types.json
  def create
    @right_type = RightType.new(right_type_params)

    respond_to do |format|
      if @right_type.save
        format.html { redirect_to @right_type, notice: "Right type was successfully created." }
        format.json { render :show, status: :created, location: @right_type }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @right_type.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /right_types/1 or /right_types/1.json
  def update
    respond_to do |format|
      if @right_type.update(right_type_params)
        format.html { redirect_to @right_type, notice: "Right type was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @right_type }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @right_type.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /right_types/1 or /right_types/1.json
  def destroy
    @right_type.destroy!

    respond_to do |format|
      format.html { redirect_to right_types_path, notice: "Right type was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_right_type
      @right_type = RightType.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def right_type_params
      params.expect(right_type: [ :name, :group ])
    end
end
