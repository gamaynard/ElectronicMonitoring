## ---------------------------
##
## Script name: FY2019_DataCompiler.R
##
## Purpose of script: Brings together VTR, EM, and Dealer Data for FY2019 for
##    analytics and reporting
##
## Author: George A. Maynard
##
## Date Created: 2020-10-19
##
## Copyright (c) George Alphonse Maynard, 2020
## Email: galphonsemaynard@gmail.com
##
## ---------------------------
##
## Notes:
##   
##
## ---------------------------

## set working directory

## ---------------------------

## Set options
options(scipen = 6, digits = 4) # eliminate scientific notation
## ---------------------------

## load up the packages we will need:  (uncomment as required)
library(RJSONIO)
library(XLConnect)
library(lubridate)
library(stringdist)
library(rgdal)
library(zip)
library(sp)
library(marmap)
library(devtools)
library(dplyr)
library(sf)
## ---------------------------

## load up our functions into memory
## The marmap library is partly deprecated because of NOAA's website updates
## Users in the GitHub community have developed a new function, and the code
## below downloads the most recent version from Eric Pante's GitHub repo
source_url(
  url="https://raw.githubusercontent.com/ericpante/marmap/master/R/getNOAA.bathy.R"
)
## ---------------------------

## The three datasets that make up the basis of this analysis are the FY2019 VTR
## data (requested from GARFO), the FY2019 EM data (requested from Teem.Fish),
## and the FY2019 Dealer Data (requested from sector managers). The next step
## reads in each dataset individually. All data are housed in the Electronic 
## Monitoring directory of the CCCFA server. The default starting point for 
## file addresses is 
## "Electronic Monitoring/Georges Analyses/ElectronicMonitoring"
##
## VTR data is read in from a .csv file, which functions as a data frame 
VTR=read.csv(
  file="../../SMAST Science/Data/FY2019-eVTR-GARFO-20201007.csv"
)
## EM data is read in from a .json file which functions as a list of lists
EM=fromJSON(
  content="../ClosedAreaComparisons/FY19/RawData/NOAA_Submissions_2019.json"
)
## Dealer data is read in from a series of .xlsx and .xls files mailed
## from the sector managers. All of this data should be stored in the same 
## directory to enable gathering. the Sustainable Harvest Sector's manager sends
## both eVTR and dealer data in the same file, so it is important to load the 
## correct worksheet from that file
fileList=dir("../ClosedAreaComparisons/FY19/RawData/DealerData/")
Dealer=data.frame()
for(i in 1:length(fileList)){
  filename=paste0(
    "../ClosedAreaComparisons/FY19/RawData/DealerData/",
    fileList[i]
  )
  if(
    grepl(
      pattern="shs",
      x=filename
    )==FALSE
  ){
    if(
      grepl(
        pattern=".xlsx",
        x=filename
      )==TRUE
    ){
      partial=XLConnect::readWorksheetFromFile(
        file=filename,
        sheet=1
      )
    } else {
      if(
        grepl(
          pattern=".csv",
          x=filename
        )==TRUE
      ){
        partial=read.csv(
          file=filename
        )
      }
    }
  } else {
    partial=XLConnect::readWorksheetFromFile(
      file=filename,
      sheet="dealer"
    )
  }
  ## Sometimes the SIMM exports the first column with an extra space in the
  ## column name, so check for that and correct it if it exists
  colnames(partial)[1]=ifelse(
    grepl(
      pattern="Sector.Id",
      x=colnames(partial)[1]
      ),
    "Sector.Id",
    "ERROR"
  )
  Dealer=rbind(Dealer,partial)
}
## The next step is to turn the .json EM file into a dataframe to enable merging
## it with other records
## Rename the EM .json to EM_JSON and create a new empty EM data frame
EM_JSON=EM
EM=data.frame(
  VTR=as.numeric(),
  VESSEL=as.character(),
  HAUL_NO=as.numeric(),
  startTime=as.numeric(),
  endTime=as.numeric(),
  startLat=as.numeric(),
  startLon=as.numeric(),
  species=as.character(),
  count=as.numeric(),
  weight=as.numeric()
)
## Each trip is an item in a list
## For each trip
for(i in 1:length(EM_JSON)){
  ## Open the list item
  trip=EM_JSON[[i]]
  ## Each trip is a list of variables and dataframes
  ## Extract the VTR number
  vtr=trip$trip_id
  ## Extract the vessel name
  vessel=trip$vessel_name
  ## Extract the number of hauls
  hauls=trip$total_hauls
  ## Report discards haul by haul
  for(h in 1:hauls){
    haul=trip$hauls[[h]]
    startTime=haul[2]
    endTime=haul[3]
    startLat=haul[4]
    startLon=haul[5]
    ## Discards are listed by species
    discards=haul$discards
    for(d in 1:length(discards)){
      species=discards[[d]]$species
      count=discards[[d]]$count_discarded
      weight=discards[[d]]$pounds_discarded
      newline=data.frame(
        VTR=as.numeric(),
        VESSEL=as.character(),
        HAUL_NO=as.numeric(),
        startTime=as.numeric(),
        endTime=as.numeric(),
        startLat=as.numeric(),
        startLon=as.numeric(),
        species=as.character(),
        count=as.numeric(),
        weight=as.numeric()
      )
      newline[1,]=NA
      newline$VESSEL=as.character(newline$VESSEL)
      newline$species=as.character(newline$species)
      newline$VTR=vtr
      newline$VESSEL=toupper(
        as.character(vessel)
      )
      newline$HAUL_NO=h
      newline$startTime=startTime
      newline$endTime=endTime
      newline$startLat=startLat
      newline$startLon=startLon
      newline$species=toupper(
        as.character(species)
      )
      newline$count=count
      newline$weight=weight
      EM=rbind(EM,newline)
      rm(newline)
    }
  }
}
## Create interoperable data sets that have all the information of interest
## Read in the species standardization list
species=read.csv(
  "https://raw.githubusercontent.com/gamaynard/ElectronicMonitoring/master/species.csv"
)
## ---------------------------
## VTR data
iVTR=VTR[,c(
  "DATE_SAIL",
  "DATE_LAND",
  "VESSEL_PERMIT_NUM",
  "SERIAL_NUM",
  "GEARCODE",
  "GEARQTY",
  "GEARSIZE",
  "AREA",
  "LAT_DEGREE",
  "LAT_MINUTE",
  "LAT_SECOND",
  "LON_DEGREE",
  "LON_MINUTE",
  "LON_SECOND",
  "NTOWS",
  "DATETIME_HAUL_START",
  "DATETIME_HAUL_END",
  "SPECIES_ID",
  "KEPT",
  "DISCARDED",
  "PORT_LANDED"
)]
colnames(iVTR)=tolower(
  colnames(iVTR)
)
## SAILDATE should be a POSIX value
iVTR$SAILDATE=ymd_hms(
  as.character(iVTR$date_sail)
  )
## LANDDATE should be a POSIX value
iVTR$LANDDATE=ymd_hms(
  as.character(iVTR$date_land)
)
## PERMIT should be a character string
iVTR$PERMIT=as.character(
  iVTR$vessel_permit_num
)
## Check for NA values in the seconds columns of both latitude and longitude
## and if they exist, replace them with zeros
iVTR$lat_second=ifelse(
  is.na(iVTR$lat_second),
  0,
  iVTR$lat_second
)
iVTR$lon_second=ifelse(
  is.na(iVTR$lon_second),
  0,
  iVTR$lon_second
)
## All longitude values should be west of the Prime Meridian (negative)
iVTR$lon_degree=ifelse(
  iVTR$lon_degree>0,
  iVTR$lon_degree*-1,
  iVTR$lon_degree
)
## Combine degrees, minutes, and seconds into decimal degrees for both latitude
## and longitude
iVTR$LAT=iVTR$lat_degree+iVTR$lat_minute/60+iVTR$lat_second/(60^2)
iVTR$LON=iVTR$lon_degree-iVTR$lon_minute/60-iVTR$lon_second/(60^2)
## Replace Gear Codes with human-readable values
iVTR$GEAR=ifelse(iVTR$gearcode=="GNS","GILLNET",
  ifelse(iVTR$gearcode=="HND","JIG",
    ifelse(iVTR$gearcode=="LLB","LONGLINE",
      ifelse(iVTR$gearcode=="OTF","TRAWL",
        ifelse(iVTR$gearcode=="PTL","LOBSTER POT",
          iVTR$gearcode
          )
        )
      )
    )
  )
## Ensure stat areas are reported as numbers
iVTR$AREA=as.numeric(
  as.character(
    iVTR$area
  )
)
## Trim serial numbers to generate VTR numbers
iVTR$VTR=NA
iVTR$VTR=ifelse(
  nchar(iVTR$serial_num)==16,
  substr(
    iVTR$serial_num,1,14
    ),
  iVTR$VTR
)
## Any trips with paper trip reports only have an 8 character identifier and
## should be excluded from this analysis, as they are likely declared out of
## fishery
iVTR=subset(
  iVTR,
  nchar(iVTR$serial_num)==16
)
## Standardize species names
iVTR$SPECIES=NA
for(i in 1:nrow(iVTR)){
  iVTR$SPECIES[i]=as.character(
    species$AFS[
      which(
        stringsim(
          a=as.character(iVTR$species_id[i]),
          b=as.character(species$PEBKAC)
        )==max(  
          stringsim(
            a=as.character(iVTR$species_id[i]),
            b=as.character(species$PEBKAC)
          )
        )
      )[1]
      ]
  )
}
## Haul start and end times should be POSIX formatted values
iVTR$HAULSTART=ymd_hms(
  as.character(
    iVTR$datetime_haul_start
    )
  )
iVTR$HAULEND=ymd_hms(
  as.character(
    iVTR$datetime_haul_end
  )
)
## Kept and discarded weights should be numeric
iVTR$KEPT=as.numeric(
  as.character(
    iVTR$kept
    )
  )
iVTR$DISCARDED=as.numeric(
  as.character(
    iVTR$discarded
  )
)
## Some VTR records only have a "serial number" instead of a 
## ---------------------------
## EM data
## because the EM data frame is already a modification of the original data, the
## script works on it directly
## The VTR column is already a character vector (to avoid loss of leading zeros)
## The VESSEL column is already a character vector
## The HAUL_NO column is already an integer
## The startTime column needs to be converted to a POSIX value
EM$STARTTIME=ymd_hm(
  as.character(
    EM$startTime
    )
  )
## The endTime column needs to be converted to a POSIX value
EM$ENDTIME=ymd_hm(
  as.character(
    EM$endTime
  )
)
## The startLat column needs to be converted to a number
EM$STARTLAT=as.numeric(
  as.character(
    EM$startLat
  )
)
## The startLon column needs to be converted to a number
EM$STARTLON=as.numeric(
  as.character(
    EM$startLon
  )
)
## Create a standardized species column
EM$SPECIES=NA
for(i in 1:nrow(EM)){
  EM$SPECIES[i]=as.character(
    species$AFS[
      which(
        stringsim(
          a=as.character(EM$species[i]),
          b=as.character(species$PEBKAC)
        )==max(  
          stringsim(
            a=as.character(EM$species[i]),
            b=as.character(species$PEBKAC)
          )
        )
      )[1]
    ]
  )
}
## Discard Count needs to be a number
EM$DiscardCount=as.numeric(
  as.character(
    EM$count
    )
  )
## DiscardWeight needs to be a number
EM$DiscardWeight=as.numeric(
  as.character(
    EM$weight
  )
)
## ---------------------------
## Dealer data
iDealer=Dealer[,c(
  "Mri",
  "Vessel.Permit.No",
  "Vessel.Name",
  "Vessel.Reg.No",
  "Vtr.Serial.No",
  "State.Land",
  "Port.Land",
  "Species.Itis",
  "Landed.Weight",
  "Live.Weight",
  "Date.Sold"
)]
## Permit numbers should be character strings to maintain leading zeros
iDealer$PERMIT=as.character(
  iDealer$Vessel.Permit.No
  )
## Vessel names should be all caps
iDealer$VESSEL=toupper(
  as.character(
    iDealer$Vessel.Name
  )
)
## VTR numbers should be character strings to maintain leading zeros
iDealer$VTR=as.character(
  iDealer$Vtr.Serial.No
  )
## Species names can be converted directly frim ITIS numbers
iDealer$SPECIES=NA
for(i in 1:nrow(iDealer)){
  itis=iDealer$Species.Itis[i]
  iDealer$SPECIES[i]=as.character(
    unique(
      species[
        which(
          species$ITIS==itis
        ),
        "AFS"
      ]
    )
  )
}
## Live weights should be reported as numbers
iDealer$WEIGHT=as.numeric(
  as.character(
    iDealer$Live.Weight
  )
)
## Dates should be converted to POSIX values
iDealer$DATE=ymd(
  as.character(
    iDealer$Date.Sold
    )
  )
## Convert permit numbers in the iVTR file to vessel names using the
## reference values available in the iDealer file
iVTR$VESSEL=NA
for(i in 1:nrow(iVTR)){
  if(iVTR$PERMIT[i]%in%iDealer$PERMIT){
    iVTR$VESSEL[i]=unique(
      iDealer$VESSEL[which(
        iDealer$PERMIT==iVTR$PERMIT[i]
      )]
    )
  } else {
    iVTR$VESSEL[i]=NA
  }
}
iVTR=subset(
  iVTR,
  is.na(iVTR$VESSEL)==FALSE
)
## Read in the audit selection file provided by TEEM FISH to double check the
## results
AUDIT=readWorksheetFromFile(
  file="../ClosedAreaComparisons/FY19/RawData/Copy of 20200604_EFP_EM2_selected_trips.xlsx",
  sheet=1
)
## Create a list of all potential VTR numbers in each data set
AV=c(
  unique(EM$VTR),
  unique(iDealer$VTR),
  unique(iVTR$VTR),
  unique(subset(
    AUDIT,
    AUDIT$AUDIT_SELECTED==1
  )$TRIP_ID)
)
## Remove duplicate values
AV=subset(
  AV,
  duplicated(AV)==FALSE
)
## Create an empty data frame to store comparisons
QC=data.frame(
  VTR_SERIAL=as.character(),
  AUDIT=as.logical(),
  VTR=as.logical(),
  EM=as.logical()
)
for(i in AV){
  qc=data.frame(
    VTR_SERIAL=as.character(i),
    AUDIT=i%in%AUDIT$TRIP_ID,
    VTR=i%in%iVTR$VTR,
    EM=i%in%EM$VTR
  )
  QC=rbind(QC,qc)
}
## After conversations with TEEM FISH staff, it was determined that one 
## group of trips were included erroneously (should be in FY18, not FY19)
## so those data should be removed from the EM dataframe
kill=as.character(
  subset(
    QC,
    QC$AUDIT==FALSE&QC$VTR==FALSE&QC$EM==TRUE
  )$VTR_SERIAL
)
EM=subset(
  EM,
  EM$VTR%in%kill==FALSE
)
## ---------------------------
## All data are standardized and ready for analysis
## ---------------------------
## Create a new data frame to store information about whether trips took place 
## inside closed areas or not
CA=data.frame(
  VTR=as.character(),
  LAT=as.numeric(),
  LON=as.numeric(),
  CAII=as.logical(),
  CL=as.logical(),
  WGOM=as.logical(),
  OUT=as.logical()
)
## Read in spatial data for all EM reviews
for(i in 1:nrow(EM)){
  vtr=EM$VTR[i]
  lat=EM$STARTLAT[i]
  lon=EM$STARTLON[i]
  new=data.frame(
    VTR=as.character(vtr),
    LAT=as.numeric(lat),
    LON=as.numeric(lon),
    CAII=NA,
    CL=NA,
    WGOM=NA,
    OUT=NA
  )
  CA=rbind(CA,new)
  rm(new)
}
## Read in spatial data for all VTRs
for(i in 1:nrow(iVTR)){
  vtr=iVTR$VTR[i]
  lat=iVTR$LAT[i]
  lon=iVTR$LON[i]
  new=data.frame(
    VTR=as.character(vtr),
    LAT=as.numeric(lat),
    LON=as.numeric(lon),
    CAII=NA,
    CL=NA,
    WGOM=NA,
    OUT=NA
  )
  CA=rbind(CA,new)
  rm(new)
}
## Remove all duplicate entries from the spatial data frame
CA$dup=duplicated(CA)
CA=subset(
  CA,
  CA$dup==FALSE
)
CA$dup=NULL
## Remove all trips with a malfunctioning GPS
CA=subset(
  CA,
  CA$LAT>20 & abs(CA$LON)>20
)
## Add a column to record whether a trip was audited or not
CA$EM=NA
## Download groundfish closures from the NOAA website as a .zip archive of 
## shapefiles into a temporary file
dest_file="AllCA.zip"
urlzip="https://s3.amazonaws.com/media.fisheries.noaa.gov/2020-09/Groundfish_Closure_Areas_20180409_0.zip?ON7sHgWHiJxpWm.B1IW5REVNRKhUvMrz"
download.file(
  url=urlzip,
  destfile=dest_file,
  mode="wb"
)
zip::unzip(
  zipfile=dest_file,
  exdir="AllCA"
)
## Read in the shapefile that contains all closed areas
AllCA=readOGR(
  dsn="AllCA/Groundfish_Closure_Areas/Groundfish_Closure_Areas.shp"
)
## Convert the shapefile from NAD83 (the default projection from NOAA) to
## WGS84 (the default projection for GEBCO, for plotting over bathymetry)
AllCA=spTransform(
  AllCA, 
  CRS("+init=epsg:4326")
  )
## Break up the shapefile into individual closed areas
## In FY2019, the closed area list includes the following:
## Cashes Ledge Closure
CL=AllCA[AllCA$AREANAME=="Cashes Ledge Closure Area",]
## Closed Area II
CA2=AllCA[AllCA$AREANAME=="Closed Area II Closure Area",]
## Western Gulf of Maine
WGOM=AllCA[AllCA$AREANAME=="Western Gulf of Maine Closure Area",]

## Remove the temporary files from the directory
unlink("AllCA.zip")
unlink(
  "AllCA",
  recursive=TRUE
  )
## Download groundfish stock areas from the NOAA website as a .zip archive  
## of shapefiles into a temporary file
dest_file="AllStocks.zip"
urlzip="https://www.fisheries.noaa.gov/webdam/download/97266468"
download.file(
  url=urlzip,
  destfile=dest_file,
  mode="wb"
)
zip::unzip(
  zipfile=dest_file,
  exdir="AllStocks"
)
## Read in the shapefile that contains all closed areas
AllStocks=readOGR(
  dsn="AllStocks/Stock_Areas/Stock_Areas.shp"
)
## Convert the shapefile from NAD83 (the default projection from NOAA) to
## WGS84 (the default projection for GEBCO, for plotting over bathymetry)
AllStocks=spTransform(
  AllStocks, 
  CRS("+init=epsg:4326")
)
## Break up the shapefile into individual stock areas and select out cod 
## stock areas
## In FY2019, the cod stock area list includes the following:
## Gulf of Maine
GOM=AllStocks[AllStocks$AREANAME=="GOM Cod Stock Area",]
## Georges Bank
GB=AllStocks[AllStocks$AREANAME=="GB Cod Stock Area",]

## Remove the temporary files from the directory
unlink("AllStocks.zip")
unlink(
  "AllStocks",
  recursive=TRUE
)
## Create an empty column for cod stock area
CA$STOCK=NA
for(i in 1:nrow(CA)){
  ## Separate the individual trip out
  trip=CA[i,]
  ## Assign the trip a spatial reference
  coordinates(trip)=~LON+LAT
  ## Reproject the trip to the same coordinate system as the closed area 
  ## shapefiles
  proj4string(trip)="+proj=longlat +datum=NAD83 +no_defs +ellps=GRS80 +towgs84=0,0,0"
  trip=spTransform(
    trip, 
    CRS("+init=epsg:4326")
  )
  ## Check to see if each trip overlaps with the boundaries of Cashes Ledge
  if(is.na(over(trip,CL)$AREANAME)==TRUE){
    CA$CL[i]=FALSE
  } else {
    CA$CL[i]=ifelse(
      as.character(over(trip,CL)$AREANAME)=="Cashes Ledge Closure Area",
      TRUE,
      FALSE
    )
  }
  ## Check to see if each trip overlaps with the boundaries of Closed Area II
  if(is.na(over(trip,CA2)$AREANAME)==TRUE){
    CA$CAII[i]=FALSE
  } else {
    CA$CAII[i]=ifelse(
      as.character(over(trip,CA2)$AREANAME)=="Closed Area II Closure Area",
      TRUE,
      FALSE
    )
  }
  ## Check to see if each trip overlaps with the boundaries of the WGOM
  if(is.na(over(trip,WGOM)$AREANAME)==TRUE){
    CA$WGOM[i]=FALSE
  } else {
    CA$WGOM[i]=ifelse(
      as.character(over(trip,WGOM)$AREANAME)=="Western Gulf of Maine Closure Area",
      TRUE,
      FALSE
    )
  }
  ## If the trips do not take place in a closed area, label them as OUT
  CA$OUT[i]=ifelse(
    CA$CAII[i]+CA$CL[i]+CA$WGOM[i]==0,
    TRUE,
    FALSE
  )
  ## Check to see if the trips are in the GB or GOM cod stock area
  if(is.na(over(trip,GOM)$AREANAME)==FALSE){
    CA$STOCK[i]=ifelse(
      as.character(over(trip,GOM)$AREANAME)=="GOM Cod Stock Area",
      "GOM",
      CA$STOCK[i]
    )
  }
  if(is.na(over(trip,GB)$AREANAME)==FALSE){
    CA$STOCK[i]=ifelse(
      as.character(over(trip,GB)$AREANAME)=="GB Cod Stock Area",
      "GB",
      CA$STOCK[i]
    )
  }
  ## Check each trip to see if it was audited by the EM program
  CA$EM=ifelse(
    CA$VTR%in%EM$VTR,
    TRUE,
    FALSE
  )
}

## Link each VTR in the CA table with a vessel name
CA$VESSEL=NA
for(i in 1:nrow(CA)){
  if(as.character(CA$VTR[i])%in%as.character(iVTR$VTR)){
    CA$VESSEL[i]=as.character(
      unique(
        iVTR$VESSEL[which(
          iVTR$VTR==as.character(
            CA$VTR[i]
          )
        )
        ]
      )
    )
  }
}
## If linking by VTR number fails, try linking by permit number
## Create a list of permit numbers from the EM data to augment the dealer data
empn=select(EM,VTR,VESSEL)
empn$PN=substr(
  x=EM$VTR,
  start=1,
  stop=6
)
empn$VTR=NULL
empn$dup=duplicated(empn)
empn=subset(
  empn,
  empn$dup==FALSE
  )
empn$dup=NULL
for(i in 1:nrow(CA)){
  if(
    is.na(CA$VESSEL[i])
  ){
    pn=substr(
      x=CA$VTR[i],
      start=1,
      stop=6
    )
    if(pn%in%iDealer$Vessel.Permit.No){
      CA$VESSEL[i]=unique(
        iDealer[which(
          iDealer$Vessel.Permit.No==pn
        ),]$VESSEL
      )
    } else {
      if(pn%in%empn$PN){
        CA$VESSEL[i]=empn$VESSEL[which(empn$PN==pn)]
      }
    }
  }
}
## Make a list of all unique vessels in the CA data frame
VESSEL=unique(CA$VESSEL)[order(
  unique(CA$VESSEL)
  )]
VESSEL=subset(VESSEL,is.na(VESSEL)==FALSE)
##########################################################################
## Table 1a is CAV
##########################################################################
## Create a table to store trips by closed area and vessel
CAV=data.frame(
  VESSEL=as.character(),
  CAII=as.numeric(),
  CL=as.numeric(),
  WGOM=as.numeric(),
  OUT=as.numeric()
)
## For each vessel, total up how many trips it took inside and outside of the
## closed areas
for(i in 1:length(VESSEL)){
  v=VESSEL[i]
  x=subset(CA,CA$VESSEL==v)
  ca2=sum(x$CAII)
  cl=sum(x$CL)
  wg=sum(x$WGOM)
  o=sum(x$OUT)
  y=data.frame(
    VESSEL=v,
    CAII=ca2,
    CL=cl,
    WGOM=wg,
    OUT=o
  )
  CAV=rbind(CAV,y)
}
##########################################################################

##########################################################################
## Table 1b is a new table that shows the number of trips a vessel took vs
## the number of trips that were audited. 
##########################################################################
CAA=data.frame(
  VESSEL=as.character(),
  TRIPS=as.numeric(),
  AUDITED=as.numeric()
)
for(i in 1:length(VESSEL)){
  v=VESSEL[i]
  x=subset(CA,CA$VESSEL==v)
  trips=nrow(x)
  a=sum(x$EM)
  y=data.frame(
    VESSEL=v,
    TRIPS=trips,
    AUDITED=a
  )
  CAA=rbind(CAA,y)
}
##########################################################################
##########################################################################
## Code to plot Figure 1 below
## WARNING: AS OF 2020-11-20, SOME OF THESE TRIPS ARE APPEARING ON LAND AND
## I'M NOT SURE WHY. FURTHER INVESTIGATION WILL BE REQUIRED TO SORT THEM OUT
##########################################################################
## Create a vector of blues for plotting a map of trips
blues=c(
  "lightsteelblue4", 
  "lightsteelblue3", 
  "lightsteelblue2", 
  "lightsteelblue1"
  )
## Create a vector of grays for plotting a map of trips
grays=c(
  gray(0.6), 
  gray(0.93), 
  gray(0.99)
  )
## Download bathymetric data for plotting trip locations
basemap=getNOAA.bathy(
  lon1=-75, 
  lon2=-65, 
  lat1=40, 
  lat2=48, 
  resolution=1
  )
## Plot the bathymetric map as a background
plot(
  basemap, 
  image = TRUE, 
  land = TRUE, 
  deep=-100000, 
  shallow=0, 
  step=999999, 
  drawlabels = FALSE, 
  bpal = list(
    c(
      min(basemap,na.rm=TRUE),
      0, 
      blues
      ), 
    c(
      0, 
      max(basemap, na.rm=TRUE), 
      grays
      )
    ), 
  lwd = 0.1
  )
## Plot the cod stock areas
plot(
  GB,
  lwd=2,
  add=TRUE
)
plot(
  GOM,
  lwd=2,
  add=TRUE
)
## Add a point for each of the trips (red for unaudited, blue for audited)
points(
  x=subset(CA,CA$EM==FALSE)$LON,
  y=subset(CA,CA$EM==FALSE)$LAT,
  pch=22,
  col='black',
  bg='red'
  )
points(
  x=subset(CA,CA$EM==TRUE)$LON,
  y=subset(CA,CA$EM==TRUE)$LAT,
  pch=22,
  col='black',
  bg='blue'
)
## Add the Closed Area shapes
plot(
  AllCA,
  lwd=1,
  add=TRUE,
  dens=25,
  angle=45,
  col='yellow'
)
plot(
  AllCA,
  lwd=3,
  add=TRUE,
  border='yellow'
)

##########################################################################
## Cod Discard Records
## Create an empty data frame to store the records
CodDiscards=data.frame(
  VTR=as.character(),
  CD=as.numeric(),
  DISCARD_SOURCE=as.character()
)
## For each trip, pull EM data (if available). If not, use the VTR data.
for(i in 1:nrow(CA)){
  trip=CA$VTR[i]
  em=subset(EM,EM$VTR==trip)
  if(nrow(em)>0){
    coddisc=sum(
      subset(em,em$SPECIES=="ATLANTIC COD")$DiscardWeight,
      na.rm=TRUE
    )
    cd=data.frame(
      VTR=trip,
      CD=coddisc,
      DISCARD_SOURCE="EM"
    )
  } else {
    vtr=subset(iVTR,iVTR$VTR==trip)
    coddisc=sum(
      subset(vtr,vtr$SPECIES=="ATLANTIC COD")$DISCARDED,
      na.rm=TRUE
    )
    cd=data.frame(
      VTR=trip,
      CD=coddisc,
      DISCARD_SOURCE="VTR"
    )
  }
  CodDiscards=rbind(CodDiscards,cd)
}
## Remove duplicate records
CodDiscards$dup=duplicated(CodDiscards)
CodDiscards=subset(
  CodDiscards,
  CodDiscards$dup==FALSE
)
CodDiscards$dup=NULL
## Add in closed area info
CodDiscards$CAII=FALSE
CodDiscards$CL=FALSE
CodDiscards$WGOM=FALSE
CodDiscards$OUT=FALSE
for(i in 1:nrow(CodDiscards)){
  x=subset(CA,CA$VTR==CodDiscards$VTR[i])
  CodDiscards$CAII[i]=sum(x$CAII)>0
  CodDiscards$CL[i]=sum(x$CL)>0
  CodDiscards$WGOM[i]=sum(x$WGOM)>0
  CodDiscards$OUT[i]=sum(x$OUT)>0
}
CodDiscards$MIX=(CodDiscards$CAII+CodDiscards$CL+CodDiscards$WGOM+CodDiscards$OUT)>1
## Add in Vessel names and cod stock areas
CodDiscards$VESSEL=NA
CodDiscards$STOCK=NA
for(i in 1:nrow(CodDiscards)){
  CodDiscards$VESSEL[i]=subset(
    CA,
    CA$VTR==CodDiscards$VTR[i]
  )$VESSEL[1]
  CodDiscards$STOCK[i]=subset(
    CA,
    CA$VTR==CodDiscards$VTR[i]
  )$STOCK[1]
}
## Add in landings values
CodDiscards$KALL=0
CodDiscards$HADDOCK=0
CodDiscards$COD=0
CodDiscards$LANDINGS_SOURCE=NA
for(i in 1:nrow(CodDiscards)){
  l=subset(
    iDealer,
    iDealer$Vtr.Serial.No==CodDiscards$VTR[i]
  )
  if(nrow(l)==0){
    v=subset(
      iVTR,
      iVTR$VTR==CodDiscards$VTR[i]
    )
    if(nrow(v)==0){
      v=subset(
        EM,
        EM$VTR==CodDiscards$VTR[i]
      )
      start=floor_date(
        min(v$STARTTIME),
        unit="day"
      )
      end=ceiling_date(
        max(v$ENDTIME),
        unit="day"
      )
    } else {
      start=floor_date(
        min(v$SAILDATE),
        unit="day"
        )
      end=ceiling_date(
        max(v$LANDDATE),
        unit="day"
      )
    }
    ves=v$VESSEL[1]
    l=subset(
      iDealer,
      iDealer$VESSEL==ves&iDealer$DATE%in%seq(
        from=start,
        to=end+86400,
        by="day"
      )
    )
  }
  CodDiscards$KALL[i]=sum(
    l$WEIGHT,
    na.rm=TRUE
    )
  CodDiscards$HADDOCK[i]=sum(
    subset(
      l,
      l$SPECIES=="HADDOCK"
    )$WEIGHT,
    na.rm=TRUE
  )
  CodDiscards$COD[i]=sum(
    subset(
      l,
      l$SPECIES=="ATLANTIC COD"
    )$WEIGHT,
    na.rm=TRUE
  )
  if(nrow(l)>0){
    CodDiscards$LANDINGS_SOURCE[i]="DEALER"
  }
}
## For records that still have blanks because the dealer data can't be
## linked or isn't available, use the self-reported VTR data to compile
## landings
for(i in 1:nrow(CodDiscards)){
  if(CodDiscards$KALL[i]==0){
    x=subset(
      iVTR,
      iVTR$VTR==CodDiscards$VTR[i]
    )
    if(nrow(x)>0){
      ## Calculcate KALL
      CodDiscards$KALL[i]=sum(
        x$KEPT,
        na.rm=TRUE
      )
      ## Calculate HADDOCK landings
      CodDiscards$HADDOCK[i]=sum(
        subset(
          x,
          x$SPECIES=="HADDOCK"
        )$KEPT
      )
      ## Calculate COD landings
      CodDiscards$COD[i]=sum(
        subset(
          x,
          x$SPECIES=="ATLANTIC COD"
        )$KEPT
      )
      ## Label the record
      CodDiscards$LANDINGS_SOURCE[i]="VTR"
    }
  }
}
## Analyze only those trips that report cod landings or discards
CodD=subset(
  CodDiscards,
  (CodDiscards$CD+CodDiscards$COD)>0
)
## Flag trips without landings data
CodD$LANDINGS=ifelse(
  CodD$KALL==0,
  FALSE,
  TRUE
)
table(CodD$LANDINGS_SOURCE)
table(CodD$DISCARD_SOURCE)
## Assign each trip to a closed area group for plotting purposes
CodD$CA=ifelse(
  CodD$CAII==TRUE,
  "CAII",
  ifelse(
    CodD$CL==TRUE,
    "CL",
    ifelse(
      CodD$WGOM==TRUE,
      "WGOM",
      "OUT"
    )
  )
)
## Assign gear type to each trip
CodD$GEAR=NA
for(i in 1:nrow(CodD)){
  g=unique(
    subset(
      iVTR,
      iVTR$VTR==CodD$VTR[i]
    )$GEAR
  )
  if(length(g)==1){
    CodD$GEAR[i]=unique(g)
  }
  if(length(g)>1){
    g=g[order(g)]
    g=paste0(g,collapse="/")
    CodD$GEAR[i]=g
  }
}
## Add Haddock:Cod ratio for Longliners
CodD$HADRAT=NA
for(i in 1:nrow(CodD)){
  if(is.na(CodD$GEAR[i])==FALSE){
    if(CodD$GEAR[i]=="LONGLINE"){
      CodD$HADRAT[i]=ifelse(
        (CodD$CD[i]+CodD$COD[i])==0,
        CodD$HADDOCK[i],
        CodD$HADDOCK[i]/(CodD$CD[i]+CodD$COD[i])
      )
    }
  }
}
#############################################################################
## CAVEATS
## 
## SOME LANDINGS DATA ARE MISSING FROM THE KATHRYN LEIGH AND MARION J
##
## SOME TRIPS ARE PLOTTING ON LAND FOR UNKNOWN REASONS (INCLUDING BOTH 
## EM-GENERATED GIS DATA AS WELL AS SELF-REPORTED DATA FROM VTRS)