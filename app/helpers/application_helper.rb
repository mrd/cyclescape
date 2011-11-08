module ApplicationHelper
  def cancel_link(url = {action: :index})
    content_tag("li", class: "cancel") do
      link_to t("cancel"), url
    end
  end

  def basic_map(&block)
    @map = core_map("map") do |map, page|
      page << map.add_layer(MapLayers::OPENCYCLEMAP)
      page << map.add_layer(MapLayers::OSM_MAPNIK)

      page << map.add_controls([OpenLayers::Control::PZ.new,
                                OpenLayers::Control::Navigation.new,
                                OpenLayers::Control::LayerSwitcher.new])

      add_formats(page)

      yield(map, page) if block_given?
    end
  end

  def tiny_display_map(object, geometry_url, &block)
    html_id = "tinymap_#{object.id}"
    @map = core_map(html_id) do |map, page|
      page << map.add_layer(MapLayers::OPENCYCLEMAP)

      add_formats(page)

      if object.location.geometry_type == RGeo::Feature::Point
        page << map.setCenter(OpenLayers::LonLat.new(object.location.x,object.location.y).transform(projection, map.getProjectionObject()),Geo::POINT_ZOOM);

        markerlayer = MapLayers::JsVar.new('markerlayer')
        icon = MapLayers::JsVar.new('icon')
        page.assign(markerlayer, OpenLayers::Layer::Markers.new( "Location", { projection: projection }))
        page << map.addLayer(markerlayer)
        page.assign(icon, OpenLayers::Icon.new('/openlayers/img/marker-blue.png'))
        page << markerlayer.addMarker(OpenLayers::Marker.new(OpenLayers::LonLat.new(object.location.x, object.location.y).transform(projection, map.getProjectionObject()), icon))
      else
        bbox = RGeo::Cartesian::BoundingBox.new(object.location.factory)
        bbox.add(object.location)
        page << map.zoomToExtent(OpenLayers::Bounds.new(bbox.min_x, bbox.min_y, bbox.max_x, bbox.max_y).transform(projection, map.getProjectionObject()))

        locationlayer = MapLayers::JsVar.new('locationlayer')
        protocol = OpenLayers::Protocol::HTTP.new( url: geometry_url, format: :format_plain )
        page.assign(locationlayer, OpenLayers::Layer::Vector.new( "Location", protocol: protocol, projection: projection, strategies: [OpenLayers::Strategy::Fixed.new() ]))
        page << map.addLayer(locationlayer)
      end
      yield(map, page, html_id) if block_given?
    end
  end

  def display_bbox_map(start_location, geometry_bbox_url, &block)
    map = basic_map do |map, page|
      if start_location.geometry_type == RGeo::Feature::Point
        page << map.setCenter(OpenLayers::LonLat.new(start_location.x, start_location.y).transform(projection, map.getProjectionObject()),start_location.z);
      else
        bbox = RGeo::Cartesian::BoundingBox.new(start_location.factory)
        bbox.add(start_location)
        page << map.zoomToExtent(OpenLayers::Bounds.new(bbox.min_x, bbox.min_y, bbox.max_x, bbox.max_y).transform(projection, map.getProjectionObject()))
      end
      vectorlayer = MapLayers::JsVar.new("vectorlayer")
      protocol = OpenLayers::Protocol::HTTP.new( url: geometry_bbox_url, format: :format_plain )
      page.assign(vectorlayer, OpenLayers::Layer::Vector.new("Issues", protocol: protocol, projection: projection, strategies: [OpenLayers::Strategy::BBOX.new()]))
      page << map.add_layer(vectorlayer)
      yield(map, page) if block_given?
    end
  end

  def projection
    OpenLayers::Projection.new("EPSG:4326")
  end

  def googleproj
    OpenLayers::Projection.new("EPSG:900913")
  end

  def user_groups(user = nil)
    user ||= current_user
    return [] if user.nil?
    user.groups
  end

  # Generate link to user or group profiles
  def link_to_profile(item)
    case item
      when User
        link_to item.name, user_profile_path(item)
      when Group
        link_to item.name, group_profile_path(item)
    end
  end

  protected

  def core_map(html_id, &block)
    map = MapLayers::Map.new(html_id, {theme: "/openlayers/theme/default/style.css",
                                        projection: googleproj,
                                        displayProjection: projection,
                                        controls: []
                                       }) do |map, page|
      yield(map, page) if block_given?
    end
  end

  def add_formats(page)
    format = MapLayers::JsVar.new("format")
    page.assign(format, OpenLayers::Format::GeoJSON.new(internalProjection: googleproj, externalProjection: projection))

    format_plain = MapLayers::JsVar.new("format_plain")
    page.assign(format_plain, OpenLayers::Format::GeoJSON.new)
  end
end
