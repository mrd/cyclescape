$(document).ready(function() {
  if ($('.user_location #user_location').length > 0) {
    var map, startSearchControl, destSearchControl, startSearchEl, destSearchEl, startLocation, userLocationPlaceholder,
        destLocation, constituencyEl, areaAroundEl, routeEl, wardEl, groupLablesEl, userLocationEl;
    map = new LeafletMap($('.map-data').data('center'), $('.map-data').data('opts'));
    startSearchControl = map.addSearchControl(
      {autoCollapse: false, collapsed: false, circleLocation: false,
        startLocation: true, textPlaceholder: 'Start/home location'}
    );
    destSearchControl = map.addSearchControl(
      {autoCollapse: false, collapsed: false, circleLocation: false,
        destLocation: true, textPlaceholder: 'Regular destination (optional)'}
    );
    startSearchEl = startSearchControl.getContainer();
    destSearchEl = destSearchControl.getContainer();
    userLocationEl = $('#user_location');
    userLocationEl.append(startSearchEl);
    $('#dest_location').append(destSearchEl);
    constituencyEl = $('.location-presets #constituency');
    wardEl = $('.location-presets #ward');
    areaAroundEl = $('.location-presets #area_around_me');
    routeEl = $('.locaton-presets #route');
    groupLablesEl = $('.group-labels');
    var nosIssues = $('#nos_issues');
    var nosIssuesDiv = $('.nos-issues');
    var updateNosIssues = function(issues){
      nosIssuesDiv.show();
      nosIssues.text(' ' + issues.features.length + ' ');
    };
    var date = new Date();
    date.setMonth(date.getMonth() - 3);
    $('[id$="_loc_json"]').change(function(e){
      $.ajax({
        url: '/api/issues',
        // jshint camelcase: false
        data: { geo_collection: $(e.target).val(), start_date: date.toJSON() },
        dataType: jsonpTransportRequired() ? 'jsonp' : void 0,
        timeout: 10000,
        success: updateNosIssues
      });
    });

    var groupChange = function(e) {
      if(e.target.checked) {
        map.drawFeatureId($(e.target).data('geo'), $(e.target).prop('id'));
      } else {
        map.drawFeatureId(null, $(e.target).prop('id'));
      }
    };

    var newGroupJson = function(groupJson) {
      groupLablesEl.text('');
      for (var g = 0, gLen = groupJson.features.length; g < gLen; g++) {
        var group = groupJson.features[g], groupName = group.properties.title, groupUrl = group.properties.url;
        var newEl = $('<label class="location-presets"><input type="checkbox" name="' +
          groupUrl + '" id="' + groupUrl +'">' + groupName + '</label>').appendTo(groupLablesEl);

        newEl.find('input').data('geo', group.geometry).change(groupChange);
      }
    };

    var changeStartLocation = function(e){
      if (userLocationPlaceholder){
        userLocationEl.find('input').attr('placeholder', userLocationPlaceholder);
      }
      constituencyEl.prop('disabled', false);
      wardEl.prop('disabled', false);
      areaAroundEl.prop('disabled', false);
      if (destLocation) {
        routeEl.prop('disabled', false);
      }
      startLocation = [e.latlng.lat, e.latlng.lng];

      $.ajax({
        url: '/api/groups',
        data: { bbox: map.map.getBounds().toBBoxString() },
        dataType: jsonpTransportRequired() ? 'jsonp' : void 0,
        timeout: 10000,
        success: newGroupJson
      });
    };

    startSearchControl.on('search_locationfound', changeStartLocation);

    destSearchControl.on('search_locationfound', function(e) {
      if (startLocation) {
        routeEl.prop('disabled', false);
      }
      destLocation = [e.latlng.lat, e.latlng.lng];
    });

    areaAroundEl.change(function(e) {
      if(e.target.checked) {
        map.drawCircle(startLocation);
      } else {
        map.drawCircle();
      }
    });

    constituencyEl.change(function(e) {
      if(e.target.checked) {
        $.ajax({
          url: '/api/constituencies',
          data: { geo: L.marker(startLocation).toGeoJSON().geometry },
          dataType: jsonpTransportRequired() ? 'jsonp' : void 0,
          timeout: 10000,
          success: function(constituencyGeo) {
            map.drawFeatureId(constituencyGeo, 'constituency');
          }
        });
      } else {
        map.drawFeatureId(null, 'constituency');
      }
    });

    wardEl.change(function(e) {
      if(e.target.checked) {
        $.ajax({
          url: '/api/wards',
          data: { geo: L.marker(startLocation).toGeoJSON().geometry },
          dataType: jsonpTransportRequired() ? 'jsonp' : void 0,
          timeout: 10000,
          success: function(constituencyGeo) {
            map.drawFeatureId(constituencyGeo, 'ward');
          }
        });
      } else {
        map.drawFeatureId(null, 'ward');
      }
    });

    routeEl.change(function(e) {
      if(e.target.checked) {
        var params = [
          { name: 'key', value: window.CONSTANTS.geocoder.apiKey },
          { name: 'itinerarypoints', value: startLocation[1] + ',' +
            startLocation[0] + '|' + destLocation[1] + ',' + destLocation[0] },
          { name: 'plan', value: 'balanced'}
        ];
        $.ajax({
          url: 'https://www.cyclestreets.net/api/journey.json?' + $.param(params),
          dataType: jsonpTransportRequired() ? 'jsonp' : void 0,
          timeout: 10000,
          success: function(json) {
            var route = L.polyline([]), points, p, pLen;
            points = json.marker[0]['@attributes'].coordinates.split(' ');
            for (p = 1, pLen = points.length; p < pLen; p++) {
              route.addLatLng(points[p].split(',').reverse());
            }
            map.drawFeatureId(route.toGeoJSON(), 'route');
          }
        });
      } else {
        map.drawFeatureId(null, 'route');
      }
    });

    if (navigator.geolocation) {
      var updateLocation = function(pos){
        var lat = pos.coords.latitude, lng = pos.coords.longitude;
        map.map.setView([lat, lng], 13);
        changeStartLocation({latlng: {lat: lat, lng: lng} });
        userLocationPlaceholder = userLocationEl.find('input').attr('placeholder');
        userLocationEl.find('input').attr('placeholder', userLocationEl.data('currentLocation'));
      };
      $('#current_location').css('display','inline-block').click(function() {
        navigator.geolocation.getCurrentPosition(updateLocation);
      });
    }
  }
});