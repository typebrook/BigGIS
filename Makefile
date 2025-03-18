.ONESHELL:

targets = VA18251 VA18252 VL00451 ORGANIC_FARMING

$(targets): tiles.list
	<$< xargs -L1 -i echo 'http://compute.geodac.tw/vectortiles/shp/$@/{}' | parallel -j 10 wget -x {}

targets: $(targets)
frompbf = $(addsuffix .geojson, $(targets))

$(frompbf).geojson:
	export target=$$(cut -d. -f1 <<<$@)
	echo target $$target >/dev/tty
	exec 1>$@
	echo -e '{\n\x20\x20"type":\x20"FeatureCollection",\n\x20\x20"features":\x20['
	find compute.geodac.tw -type f -path "*$${target}*pbf" -size +1b | \
	parallel -j8 while read pbf; do
		tile=$${pbf##*/14/}
		yx=$${tile%.pbf}
		IFS=/ read y x <<<$$yx
		echo -n x $$x y $$y >/dev/tty
		ogr2ogr -oo X=$$x -oo Y=$$y -oo Z=14 -t_srs EPSG:4326 -f GEOJSON /vsistdout/ $$pbf | \
		jq -c '.features[]'
	done | \
	tee >(nl | head -c500 >/dev/tty) | \
	sed '$$ !s/$$/,/'
	echo -e '\x20\x20]\n}'

地質圖.kml:
	curl https://geodac.ncku.edu.tw/SWCB_LLGIS/地質圖.kml -O

中央管河川.kml:
	curl https://geodac.ncku.edu.tw/SWCB_LLGIS/區域排水/區排_中央管河川.kml -O

縣市管河川.kml:
	curl https://geodac.ncku.edu.tw/SWCB_LLGIS/區域排水/區排_縣市管河川.kml -O

水道.kml:
	curl https://geodac.ncku.edu.tw/SWCB_LLGIS/區域排水/區排_水道.kml -O
