# title         : MODIS_watermask250m.R
# purpose       : Global water mask at multiple resolutions
# reference     : Worldgrids.org;
# producer      : Prepared by T. Hengl
# address       : In Wageningen, NL.
# inputs        : Global Land Cover Facility (GLCF) http://glcf.umd.edu/data/watermask/ cite as Carroll, M., Townshend, J., DiMiceli, C., Noojipady, P., Sohlberg, R. 2009. A New Global Raster Water Mask at 250 Meter Resolution. International Journal of Digital Earth. ( volume 2 number 4);
# outputs       : geotiff images projected in the WGS84 coordinate system;
# remarks 1     : This script is available from www.worldgrids.org;
# remarks 2     : the whole world is 177 tiles;
# remarks 3     : this code is Windows OS specific;

## 1. GENERAL SETTINGS:
library(rgdal)
library(raster)
# library(modis)
fw.path <- utils::readRegistry("SOFTWARE\\WOW6432NODE\\FWTools")$Install_Dir
gdalwarp <- shQuote(shortPathName(normalizePath(file.path(fw.path, "bin/gdalwarp.exe"))))
gdal_translate <- shQuote(shortPathName(normalizePath(file.path(fw.path, "bin/gdal_translate.exe"))))
gdalbuildvrt <- shQuote(shortPathName(normalizePath(file.path(fw.path, "bin/gdalbuildvrt.exe"))))
gdalinfo <- shQuote(shortPathName(normalizePath(file.path(fw.path, "bin/gdalinfo.exe"))))
crs <- "+proj=longlat +datum=WGS84"
outdir <- "G:/WORLDGRIDS/maps"

## Get 7z:
download.file("http://downloads.sourceforge.net/project/sevenzip/7-Zip/9.20/7za920.zip", destfile=paste(getwd(), "/", "7za920.zip", sep="")) 
unzip("7za920.zip")

## 2. LIST AND UNZIP ALL TILES:
pl <- list.dirs(path="G:/MODIS/MOD44W")
pl <- pl[-1]
fl <- NULL
for(j in 1:length(pl)){ 
  fl[[j]] <- list.files(pl[j], pattern="*tif.gz$", full.names = TRUE) 
  outname <- list.files(pl[j], pattern="*tif.gz$")
  if(!is.na(file.info(fl[[j]])$size)){
    if(is.na(file.info(strsplit(outname, ".gz")[[1]])$size)){
      system(paste("7za e", normalizePath(fl[[j]])))
  }}
}
system(paste(gdalinfo, strsplit(outname, ".gz")[[1]])) 

## 3. CREATE A MOSAIC AND RESAMPLE TO VARIOUS RESOLUTIONS:

## list all individual images and replace the values :(
tif.lst <- list.files(pattern="*.tif$")
fun <- function(x) { x[is.na(x)] <- 0; x <- x*100; return(x)}
for(j in 1:length(tif.lst)){
  g <- GDALinfo(tif.lst[j])
  if(attr(g, "df")$NoDataValue==0){
    r <- raster(tif.lst[j])
    r2 <- calc(r, fun)
    writeRaster(r2, tif.lst[j], overwrite=TRUE)
  }
} ## takes ca. 120 minutes!

## generate a VRT (virtual mosaic):
system(paste(gdalbuildvrt, "MOD44W.vrt *.tif"))
## Create a mosaick:
#unlink("WMKMOD5a.tif")
#system(paste(gdalwarp, ' MOD44W.vrt WMKMOD5a.tif -t_srs \"', crs, '\" -srcnodata 0 -dstnodata -9999 -ot \"Int16\" -r near -te -180 -90 180 90 -tr ', 1/480,' ', 1/480, sep=""))  ## 5 MINS
unlink("WMKMOD3a.tif")
system(paste(gdalwarp, ' MOD44W.vrt WMKMOD3a.tif -t_srs \"', crs, '\" -r bilinear -ot \"Byte\" -dstnodata 255 -te -180 -90 180 90 -tr ', 1/120,' ', 1/120, sep=""), show.output.on.console = TRUE)  ## 5 MINS
system(paste(gdalwarp, ' WMKMOD3a.tif WMKMOD2a.tif -t_srs \"', crs, '\" -r bilinear -ot \"Byte\" -dstnodata 255 -te -180 -90 180 90 -tr ', 1/40,' ', 1/40, sep=""))
system(paste(gdalwarp, ' WMKMOD3a.tif WMKMOD1a.tif -t_srs \"', crs, '\" -r bilinear -ot \"Byte\" -dstnodata 255 -te -180 -90 180 90 -tr ', 1/20,' ', 1/20, sep=""))
system(paste(gdalwarp, ' WMKMOD3a.tif WMKMOD0a.tif -t_srs \"', crs, '\" -r bilinear -ot \"Byte\" -dstnodata 255 -te -180 -90 180 90 -tr ', 1/5,' ', 1/5, sep=""))
system(paste(gdalwarp, ' WMKMOD3a.tif wmask.tif -t_srs \"', crs, '\" -r bilinear -ot \"Byte\" -dstnodata 255 -te -180 -90 180 90 -tr ', 1,' ', 1, sep=""))


## Zip the output files:
for(i in 0:3){
  outname = paste("WMKMOD", i, 'a', sep="")
  system(paste("7za a", "-tgzip -mx=9", set.file.extension(outname, ".tif.gz"), set.file.extension(outname, ".tif"))) 
  system(paste("xcopy", normalizePath(set.file.extension(outname, ".tif.gz")), shortPathName(normalizePath(outdir))))
  unlink(set.file.extension(outname, ".tif.gz"))
}

## end of script;