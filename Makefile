.ONESHELL:

z=13
targets = VA18251 VA18252 VL00451 ORGANIC_FARMING

taiwan.outline:
	curl -sL https://cdn.jsdelivr.net/npm/taiwan-atlas/nation-10t.json | \
	ogr2ogr -f GEOJSON $@ "/vsistdin?buffer_limit=-1/"

tiles.list: taiwan.outline
	trap 'rm -rf tileset' EXIT
	ogr2ogr -f MVT -dsco MINZOOM=$(z) -dsco MAXZOOM=$(z) tileset/ $<
	find tileset/ -type f -name '*pbf' >$@

$(targets): tiles.list
	sed -E 's@^[^0-9]+(.*)[.].*@\1@' $< | \
	while IFS=/ read -r z x y; do
		echo http://compute.geodac.tw/vectortiles/shp/$@/$$z/$$y/$$x.pbf
	done | parallel -j 10 wget -x {}

targets: $(targets)
frompbf = $(addsuffix .geojson, $(targets))

$(frompbf):
	export tmp=tmp.geojsonseq
	#trap 'rm $$tmp 2>/dev/null' EXIT
	export z=$${z:-$(z)}
	export target=$$(cut -d. -f1 <<<$@)
	export cols=a_area,autho_name,authority,county,countyname,d_code,gid,p_area,p_date,p_docno,slopeland
	echo target $$target >/dev/tty
	find compute.geodac.tw/vectortiles/shp/$${target}/$${z} -type f -name "*pbf" -size +1b | \
	nl | \
	while read num pbf; do
		echo reading $$pbf >/dev/tty
		tile=$${pbf##*/$${z}/}
		yx=$${tile%.pbf}
		IFS=/ read y x <<<$$yx
		cat <<-COMMAND
			echo -en $$num '\t\t' $$yx '\r' >/dev/tty; \
			ogr2ogr -oo X=$$x -oo Y=$$y -oo Z=$$z -t_srs EPSG:4326 -of GeoJSONSeq /vsistdout/ $$pbf
		COMMAND
	done | \
	parallel -j8 bash -c >$$tmp
	ogr2ogr \
		-dialect sqlite \
		-sql "SELECT p_docno,countyname,ST_UNION(geometry) AS geometry from tmp GROUP BY p_docno,countyname" \
		$$target.geojson $$tmp

地質圖.geojson:
	curl https://geodac.ncku.edu.tw/SWCB_LLGIS/地質圖.kml | \
	ogr2ogr $@ "/vsistdin?buffer_limit=-1/"

中央管河川.geojson:
	curl https://geodac.ncku.edu.tw/SWCB_LLGIS/區域排水/區排_中央管河川.kml | \
	ogr2ogr $@ "/vsistdin?buffer_limit=-1/"

縣市管河川.geojson:
	curl https://geodac.ncku.edu.tw/SWCB_LLGIS/區域排水/區排_縣市管河川.kml | \
	ogr2ogr $@ "/vsistdin?buffer_limit=-1/"

水道.geojson:
	curl https://geodac.ncku.edu.tw/SWCB_LLGIS/區域排水/區排_水道.kml | \
	ogr2ogr $@ "/vsistdin?buffer_limit=-1/"

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
