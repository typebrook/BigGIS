.ONESHELL:

targets = VA18251 VA18252 VL00451 ORGANIC_FARMING

$(targets): tiles.list
	<$< xargs -L1 -i echo 'http://compute.geodac.tw/vectortiles/shp/$@/{}' | parallel -j 10 wget -x {}

targets: $(targets)
frompbf = $(addsuffix .geojson, $(targets))

$(frompbf):
	export target=$$(cut -d. -f1 <<<$@)
	echo target $$target >/dev/tty
	find compute.geodac.tw -type f -path "*$${target}*pbf" -size +1b | \
	nl | \
	while read num pbf; do
		tile=$${pbf##*/14/}
		yx=$${tile%.pbf}
		IFS=/ read y x <<<$$yx
		cat <<-COMMAND
			echo -en $$num '\t\t' $$yx '\r' >/dev/tty; \
			ogr2ogr -oo X=$$x -oo Y=$$y -oo Z=14 -t_srs EPSG:4326 -f GEOJSONSeq /vsistdout/ $$pbf
		COMMAND
	done | \
	parallel -j8 bash -c | \
	ogr2ogr -skipfailures -if GEOJSONSeq $$target.geojson /vsistdin/

地質圖.kml:
	curl https://geodac.ncku.edu.tw/SWCB_LLGIS/地質圖.kml -O

中央管河川.kml:
	curl https://geodac.ncku.edu.tw/SWCB_LLGIS/區域排水/區排_中央管河川.kml -O

縣市管河川.kml:
	curl https://geodac.ncku.edu.tw/SWCB_LLGIS/區域排水/區排_縣市管河川.kml -O

水道.kml:
	curl https://geodac.ncku.edu.tw/SWCB_LLGIS/區域排水/區排_水道.kml -O

canal.geojson:
	ogr2ogr -f "GeoJSON" -t_srs EPSG:4326 $@ \
	WFS:"https://www.iacloud.ia.gov.tw/servergate/sgsgate.ashx/WFS/canal_public?SERVICE=WFS&REQUEST=GetFeature&VERSION=1.1.0&TYPENAME=canal_public&SRSNAME=EPSG:4326&BBOX=23,120,23.5,120.5,EPSG:4326"

shp:
	ls *geojson | \
	while IFS=. read layer ext; do
		ogr2ogr -oo ISO8859-1 -lco ENCODING=UTF-8 $$layer.shp.zip $$layer.$$ext;
	done

clean:
	rm *shp *shx *dbf *prj *dbf *geojson *json
