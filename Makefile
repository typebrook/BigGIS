.ONESHELL:

targets=

$(targets): tiles.list
	<$< xargs -L1 -i echo 'http://compute.geodac.tw/vectortiles/shp/$@/{}' | parallel -j 10 wget -x {}
