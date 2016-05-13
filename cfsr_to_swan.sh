
#!/bin/bash
# cfsr_to_swan.sh  version 1.06

  #********************************************************************#
  #                                                                    #
  # Program to tranform the global CFRS wind.nc in ASCII file          #
  # readable from SWAN:                                                #
  # 1) extract a subgrid file.nc                                       #
  # 2) subset the file.nc in files with 1 time step                    #
  # 3) save wind data as ASCII files for SWAN                          #
  # 4) print inpgrd.wnd and wind.inp                                   #
  #                                                                    #
  # The program need a CFSR file.nc as argument                        #
  #                                                                    #
  #                                              Author: Dario Pelli   #
  # Last update: 3-May-2016                                            #
  #                                                                    #
  #********************************************************************#

  ######################################################################
  # User customization:
  # - define subregion
  # - define errors
  ######################################################################

  # Define a subregion
  subregion="lig"
  lat_start=42.5
  lat_end=45.
  lon_start=8.5
  lon_end=11.5
  
  # Define the variable to extract
  var1="UGRD_10maboveground"
  var2="VGRD_10maboveground"

  # Define errors
  E_NOARG=65
  E_NCKS=66 
  E_EXE=67

  ######################################################################
  # Define a function for errors of a generic process
  err_exe ()
  {
    if [ $? -ne 0 ]; then
      echo "Program aborted for error $E_EXE"
      exit $E_EXE
    fi 
  }
  ######################################################################

  # Verify the file to be processed
  if [ -z "$1" ]
  then
    echo "You must write a valid file name as argument!!"
    exit $E_NOARG
  fi  

  echo -n "Write the first and final time step: "
  read t_start t_end

  
  
  # Extract the selected subregion from the input file
  echo ---------------------------------------------------------------
  echo   "  Processing file ${1}"
  ncks -d longitude,${lon_start},${lon_end} -d latitude,${lat_start},${lat_end} \
${1} wnd.${subregion}.nc

  if [ $? -eq 0 ]; then
    echo "  File ${1} successfully processed!!"
    echo ---------------------------------------------------------------
    echo
  else
    exit $E_NCKS
  fi
 
  # Looking for extremes of lat/lon and dx,dy
  ncap2 -O -s 'latitude@dy=latitude(2)-latitude(1);
               longitude@dx=longitude(2)-longitude(1);
               latitude@min=gsl_stats_min(latitude);
               latitude@max=gsl_stats_max(latitude);
               longitude@min=gsl_stats_min(longitude);
               longitude@max=gsl_stats_max(longitude);
              ' wnd.${subregion}.nc wnd.${subregion}.nc
  
  # Print the INPgrid WInd file
  nx_ny='latitude[[:blank:]]=|longitude[[:blank:]]='
  dx_dy='longitude:dx|latitude:dy'
  extr_coord='latitude:min|latitude:max|longitude:min|longitude:max'
  ncdump -h wnd.${subregion}.nc | grep -E ${nx_ny} > inpgrd1.tmp
  ncdump -h wnd.${subregion}.nc | grep -E ${dx_dy} > inpgrd2.tmp
  ncdump -h wnd.${subregion}.nc | grep -E ${extr_coord} > inpgrd3.tmp
  cat inpgrd1.tmp inpgrd2.tmp inpgrd3.tmp > inpgrd.tmp
   
  # Arrange the inpgrd.wnd file for SWAN
  sed '1i Grid info for wind input of SWAN
       1i
       1i mx=longitude-1; 
       1i my=latitude-1; 
       s/[[:blank:]]//g' inpgrd.tmp | tee inpgrd.wnd
  rm *.tmp
  echo "**Grid info saved in inpgrd.wnd**" 

  echo
  echo   "Producing input wind files for SWAN"
 ## Start LOOP 
  for (( a=$t_start; a <= t_end; a++ )); do
      
      #subset the file in files with single time step
      ncks -d time,${a} wnd.${subregion}.nc wnd.${subregion}.${a}.nc
      err_exe
    
      # Transform each file in CDL file
      ncdump wnd.${subregion}.${a}.nc -v ${var1},${var2} > wnd.${subregion}.${a}.cdl
      err_exe

      # Delete heading, comma, semi-colon, right curly bracket, and empty lines,
      # UGRD,VGRD lines and add a new heading
      sed -e '1,/data:/d     
              s/,//g
              s/;//g
              s/}//g
              /^$/d
              ' wnd.${subregion}.${a}.cdl > wnd.${subregion}.${a}.inp
      sed -i "1i wnd.${subregion}.${a}.inp" wnd.${subregion}.${a}.inp
      err_exe

      # Delete file wnd.subregion.n.cdl and file wnd.subregion.n.nc 
      rm wnd.${subregion}.${a}.cdl
      rm wnd.${subregion}.${a}.nc

      echo "File wnd.${subregion}.${a}.inp successfully created"

  done
 ## End LOOP

  # Print wind.inp
  cat wnd.${subregion}.*.inp > wind.inp
  echo 
  echo '**Wind data files stored in wind.inp**'

  # Delete files wnd.subregion.nc and wnd.${subregion}.*.inp
    rm wnd.${subregion}.nc
    rm wnd.${subregion}.*.inp

  echo ---------------------------------------------------------------
  echo "  Program successfully executed!!"
  echo
  
  exit
  
  
  
