.ONESHELL:

# TYPE: PBF tiles
z=13
targets = VA18251 VA18252 VA18254 VA18062 VA18062 NATIONAL_PARK VL00451 ORGANIC_FARMING

.PHONY: group_by
group_by:
	cat <<EOF >$@
		VA18251	p_docno,countyname
		VA18252	p_docno,countyname
		VA18254	swcb_plan
		VA18064	gid
		NATIONAL_PARK	'分區代碼'
		VL00451	name
		ORGANIC_FARMING	'地籍址'
	EOF

taiwan.outline:
	curl -sL https://cdn.jsdelivr.net/npm/taiwan-atlas/nation-10t.json | \
	ogr2ogr -f GEOJSON $@ "/vsistdin?buffer_limit=-1/"

.PHONY: tiles.list
tiles.list: taiwan.outline
	trap 'rm -rf tileset' EXIT
	ogr2ogr -f MVT -dsco MINZOOM=$(z) -dsco MAXZOOM=$(z) tileset/ $<
	find tileset/ -type f -name '*pbf' >$@

tiles = $(addprefix tile., $(targets))
$(tiles): tiles.list
	target=$$(cut -d. -f2 <<<$@)
	sed -E 's@^[^0-9]+(.*)[.].*@\1@' $< | \
	while IFS=/ read -r z x y; do
		echo http://compute.geodac.tw/vectortiles/shp/$$target/$$z/$$y/$$x.pbf
	done | \
	parallel -j8 wget -x {}
tiles: $(tiles)

geojson_from_tiles = $(addsuffix .geojson, $(tiles))
$(geojson_from_tiles): group_by
	export target=$$(cut -d. -f2 <<<$@)
	echo target $$target >/dev/tty
	[ -d compute.geodac.tw/vectortiles/shp/$$target ] || { echo NO TILES; exit 1; }
	export z=$${z:-$(z)}
	export group_by=$$(grep $$target $< | cut -f2)
	export tmp=tmp.geojsonseq
	#trap 'rm $$tmp 2>/dev/null' EXIT
	find compute.geodac.tw/vectortiles/shp/$${target}/$${z} -type f -name "*pbf" -size +1b | \
	nl | \
	while read num pbf; do
		tile=$${pbf##*/$${z}/}
		yx=$${tile%.pbf}
		IFS=/ read y x <<<$$yx
		cat <<-COMMAND
			echo -en $$num '\t\t' $$z/$$yx '\r' >/dev/tty; \
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
	set -x
	ogr2ogr \
		-dialect sqlite \
		-sql "SELECT $${fields}ST_UNION(geometry) AS geometry from tmp GROUP BY $${group_by}" \
		$$target.geojson $$tmp

# TYPE: KML
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

# TYPE: WFS
canal.geojson:
	cat <<URL | xargs -i echo -e {}
	WFS:"\
		https://www.iacloud.ia.gov.tw/servergate/sgsgate.ashx/WFS/canal_public?\
		SERVICE=WFS&\
		REQUEST=GetFeature&\
		VERSION=1.1.0&\
		TYPENAME=canal_public&\
		SRSNAME=EPSG:4326&\
		BBOX=23,120,23.5,120.5,EPSG:4326\
	"
	URL

# OTHERS
shp:
	ls *geojson | \
	while IFS=. read layer ext; do
		ogr2ogr -oo ISO8859-1 -lco ENCODING=UTF-8 $$layer.shp.zip $$layer.$$ext;
	done

%.shp.zip: %.geojson
	ogr2ogr -oo ISO8859-1 -lco ENCODING=UTF-8 $@ $<

clean:
	rm *shp *shp.zip *shx *dbf *prj *dbf *cpg *geojsonseq *json

.PHONY: graph.svg
graph.svg:
	~/go/bin/makefile-graph \
		--makefile ./Makefile \
		--direction BT | \
	dot -Tsvg -o $@

dir: list list.dir.sh
	<$< ./$(word 2,$^) | xargs -i mkdir -p output/{}
	find output -type d -empty | xargs -i touch {}/.gitkeep
