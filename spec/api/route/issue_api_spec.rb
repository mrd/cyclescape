require 'spec_helper'

describe Route::IssueApi do
  include Rack::Test::Methods

  let(:geojson_response) { RGeo::GeoJSON.decode(last_response.body, json_parser: :json) }

  describe 'GET /' do
    context 'pagination' do
      before { create_list :issue, 201, created_by: create(:user) }

      it "has default pagination" do
        get "api/issues"
        expect(geojson_response.size).to eq(200)
      end

      it "respects pagination" do
        get "api/issues", page: 3, per_page: 100
        expect(geojson_response.size).to eq(1)
      end
    end

    context 'with a geo_collection' do
      let!(:issue) { create :issue_within_quahog }
      let(:locables) { [ build_stubbed(:quahogcc_group_profile), build_stubbed(:small_group_profile)] }
      let(:host) { "" }

      before do
        create :issue
        geo_features = locables.map { |loc| RGeo::GeoJSON::Feature.new(loc.location) }
        geo_collection = RGeo::GeoJSON.encode(RGeo::GeoJSON::FeatureCollection.new(geo_features))
        get "#{host}/api/issues", geo_collection: geo_collection.to_json
      end

      it 'returns issue' do
        expect(geojson_response.size).to eq(1)
        expect(geojson_response[0]['id']).to eq(issue.id)
        expect(last_response.status).to eq(200)
      end
    end

    context 'with bounding box' do
      let(:host) { "" }
      before do
        tag = create :tag, name: 'taga'
        create :issue_within_quahog, tags: [tag] # location 0.11906 52.20792
        create :issue, tags: [tag]
        create :issue
        get "#{host}/api/issues", bbox: '0.11905,52.20791,0.11907,52.20793', tags: ["taga"].to_json
      end

      it 'returns issue' do
        expect(geojson_response.size).to eq(1)
        expect(last_response.status).to eq(200)
      end

      it 'has the correct fields' do
        expect(geojson_response[0].keys).
          to match_array(%w(id created_at created_by deadline external_url description
                            tags cyclescape_url photo_thumb_url thumbnail title vote_count
                            latest_activity_at closed))
      end

      context 'with a subdomain' do
        let(:host) { 'http://cam.example.com' }

        it 'returns cyclescape url with subdomain' do
          expect(geojson_response[0]['cyclescape_url']).to match(%r{cam\.example\.com/issues})
        end
      end
    end

    context 'with dates' do
      before do
        create :issue, deadline: 1.day.ago, id: 4242
        create :issue, created_at: 3.days.ago, deadline: 3.days.ago
      end

      it 'respects the start date parameter' do
        get "api/issues", start_date: 2.days.ago.strftime("%Y/%m/%d")

        expect(geojson_response.size).to eq(1)
        expect(geojson_response[0]['id']).to eq(4242)
      end

      it 'respects the end date parameter' do
        get "api/issues", end_date: 2.days.ago.strftime("%Y/%m/%d")

        expect(geojson_response.size).to eq(1)
        expect(geojson_response[0]['id']).to_not eq(4242)
      end
    end

    context 'with group' do
      let!(:group_profile) { create(:quahogcc_group_profile) }
      let!(:inside_group)  { create :issue_within_quahog }
      let!(:outside_group) { create :issue }

      before do
        get "api/issues", group: group_profile.reload.group.short_name
      end

      it 'should only return issues inside the groups area' do
        expect(last_response.inspect).to include(inside_group.to_param)
        expect(geojson_response.size).to eq(1)
        expect(geojson_response[0]['id']).to eq(inside_group.id)
      end
    end

    context 'should hide issues creators if hidden' do
      let(:user)   { create :user }
      let!(:issue) { create :issue, created_by: user }

      before do
        create :user_profile, user: user, visibility: 'group'
        get "api/issues"
      end

      it 'should hide the users name' do
        expect(geojson_response[0]['created_by']).to eq('Anon')
      end
    end
  end
end
