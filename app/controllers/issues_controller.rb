class IssuesController < ApplicationController
  before_filter :authenticate_user!, only: [:new, :create]
  
  def index
    @issues = Issue.order("created_at DESC").limit(10)
    @start_location = index_start_location
  end

  def show
    @issue = Issue.find(params[:id])
    @threads = @issue.threads
  end

  def new
    @issue = Issue.new
    @start_location = current_user.start_location
  end

  def create
    @issue = current_user.issues.new(params[:issue])

    if @issue.save
      redirect_to @issue
    else
      @start_location = Geo::NOWHERE_IN_PARTICULAR
      render :new
    end
  end

  def destroy
    @issue = Issue.find(params[:id])

    if @issue.destroy
      set_flash_message(:success)
      redirect_to issues_path
    else
      set_flash_message(:failure)
      redirect_to @issue
    end
  end

  def geometry
    @issue = Issue.find(params[:id])
    respond_to do |format|
      format.json { render json: RGeo::GeoJSON.encode(@issue.location) }
    end
  end

  def all_geometries
    if params[:bbox]
      bbox = bbox_from_string(params[:bbox], Issue.rgeo_factory)
      issues = Issue.intersects(bbox.to_geometry).order("created_at DESC").limit(50)
    else
      issues = Issue.order("created_at DESC").limit(50)
    end
    factory = RGeo::Geos::Factory.new
    collection = factory.collection(issues.map { | issue | issue.location})
    respond_to do |format|
      format.json { render json: RGeo::GeoJSON.encode(collection)}
    end
  end

  def search
    @query = params[:q]
    @results = Issue.find_with_index(params[:q])
  end

  protected

  def index_start_location
    return current_user.start_location if current_user
    # TODO return subdomain.group.location if subdomain
    return @issues.last.location unless @issues.empty?
    return Geo::NOWHERE_IN_PARTICULAR
  end
end
