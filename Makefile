.ONESHELL:

z=13
targets = VA18251 VA18252 VL00451 ORGANIC_FARMING

group_by:
	cat <<EOF >$@
		VA18251			p_docno,countyname
		VA18252			p_docno,countyname
		VL00451			name
		ORGANIC_FARMING	'地籍址'
	EOF

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
	done | \
	parallel -j8 wget -x {}

targets: $(targets)
frompbf = $(addsuffix .geojson, $(targets))

$(frompbf): group_by
	export tmp=tmp.geojsonseq
	#trap 'rm $$tmp 2>/dev/null' EXIT
	export z=$${z:-$(z)}
	export target=$$(cut -d. -f1 <<<$@)
	export group_by=$$(grep $$target $< | cut -f2)
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
			ogr2ogr \
				-oo X=$$x \
				-oo Y=$$y \
				-oo Z=$$z \
				-t_srs EPSG:4326 \
				-of GeoJSONSeq /vsistdout/ \
				$$pbf
		COMMAND
	done | \
	parallel -j8 bash -c >$$tmp
	fields=$$(head -1 $$tmp | jq -r '.properties|keys[]' | tr '\n' ,)
	ogr2ogr \
		-dialect sqlite \
		-sql "SELECT $${fields}ST_UNION(geometry) AS geometry from tmp GROUP BY $${group_by}" \
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
