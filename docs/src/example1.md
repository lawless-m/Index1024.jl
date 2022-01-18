Example Indexing of a CSV file
==============================

# The Data

The CSV file I wish to index contains the data from the UK Land Registry. 
https://www.gov.uk/guidance/about-the-price-paid-data
This records the value of every house sale in England and Wales. I have gathered the data from 2000 onwards and extracted the following dataset. The postcode, year and price of every transaction.

What I want is to be able to extract the list of year / price entries for a particular postcode.

postcode,year,price       
AL10 0AB,2000,63000       
AL10 0AB,2003,126500      
AL10 0AB,2003,167000      
AL10 0AB,2003,177000      
AL10 0AB,2004,125000      
AL10 0AB,2013,220000      
AL10 0AB,2014,180000      
⋮
YO8 9YB,2021,269950
YO8 9YD,2011,230000
YO8 9YD,2012,249999
YO8 9YD,2018,327500
YO8 9YE,2009,320000
YO8 9YE,2019,380000
YO8 9YE,2020,371500
YO90 1UU,2017,15500000
YO90 1WR,2015,28100000
YO91 1RT,2017,150000

13,193,754 lines, including the header. The file size is 267,473,752 bytes.


