class Message::CyclestreetsPhotosController < Message::BaseController
  def show
    @cyclestreets_photo = CyclestreetsPhotoMessage.find params[:id]
  end

  protected

  def component
    @cyclestreets_photo ||= CyclestreetsPhotoMessage.new permitted_params
  end

  def permitted_params
    params.require(:cyclestreets_photo_message).permit(
      :photo_url, :caption, :cyclestreets_id, :icon_properties, :loc_json
    )
  end
end
