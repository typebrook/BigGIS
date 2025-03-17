.ONESHELL:

targets= VA18251 VA18252 VL00451

$(targets): tiles.list
	<$< xargs -L1 -i echo 'http://compute.geodac.tw/vectortiles/shp/$@/{}' | parallel -j 10 wget -x {}

targets: $(targets)
