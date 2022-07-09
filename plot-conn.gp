#!/usr/bin/env gnuplot -c
# Plot connection status data.
# Usage Examples:
#   $ ./plot-conn.gp                    # defaults to conn.csv, outputs to screen
#   $ ./plot-conn.gp conn.csv           # output to screen
#   $ ./plot-conn.gp conn.csv conn.png  # write output to conn.png

# Grab command line arguments
csv_file = "moniconn.csv"
png_file = ''
if (strlen(ARG1) > 0 ) csv_file = ARG1;
if (strlen(ARG2) > 0 ) png_file = ARG2;

itype = csv_file[strlen(csv_file)-3:strlen(csv_file)]
otype = ''
if ( strlen(png_file) > 0 ) {
    otype = png_file[strlen(png_file)-3:strlen(png_file)]
}
msg = 'output to screen'
if ( strlen(png_file) > 0 ) {
    msg = 'output to file'
}
bargraph_plot = 1  # 0 - line plot, 1 - bar graph
edate=system(sprintf("head -2 %s | tail -1 | awk -F, '{print $2}'", csv_file)) # skip header
ldate=system(sprintf("tail -1 %s | awk -F, '{print $2}'", csv_file))
print "script name: ", ARG0
print "input file : ", csv_file
print "output     : ", png_file
print "mode       : ", msg
print "earliest   : ", edate
print "latest     : ", ldate
if ( itype ne ".csv" ) {
    print "ERROR: unrecognized input file extension '", itype, "', must be '.csv'"
    exit
}
if ( strlen(otype) > 0 && otype ne '.png' ) {
    print "ERROR: unrecognized output file extension '", itype, "', must be '.png'"
    exit
}

# collect stats from interesting columns
# Figure out the max value for the error columns and add a bit.
set datafile separator ','
stats csv_file using 4  # success
ymax = STATS_max
total_time = STATS_sum
stats csv_file using 6  # wifi errors
ymax = STATS_max > ymax ? STATS_max : ymax
y2max = STATS_max
total_time = total_time + STATS_sum
stats csv_file using 8  # internet errors
ymax = STATS_max > ymax ? STATS_max : ymax
y2max = STATS_max > y2max ? STATS_max : y2max
total_time = total_time + STATS_sum
total_errs = STATS_sum
uptime = 100. * (1. - total_errs / total_time)
uptime_str = sprintf("%.5f%", uptime)
print "uptime: " , uptime_str

if (bargraph_plot ) {
    set yrange [0:ymax]
    set y2range [0:y2max]
}

# set title
title_string=sprintf("Service Downtime\nin %s\n%s to %s\nuptime: %s", \
                              csv_file, edate, ldate, uptime_str)

# Initialize
set datafile separator ','
set xdata time                          # tells gnuplot the x axis is time data
set timefmt "%Y-%m-%dT%H:%M:%S-07:00"   # specify our time string format
set format x "%a\n%m-%d\n%H:%M"
#set format x "%m-%dT%H:%M"
#set xtics rotate by -45

#set title "Internet Connectivity Service Downtime\nin conn.csv\n$earliest_date to $latest_date"
set title title_string
set xlabel "date/time"
set ylabel "uptime (secs)"
set y2label "downtime (secs)"

set ytics nomirror
set y2tics


# show some setup info
# show term
# show bind
#> show colornames

# setup term
if ( strlen(png_file) == 0 ) {
    # to screen
    # plot
    set term qt font "Arial,14"
    set term qt size 1440, 900
} else {
    set term png
    set term png font "Arial,14"
    set term png size 1440, 900
    set output png_file
}

# plot
#show term
#set palette model RGB defined ( 0 'forest-green', 1 'light-red' )
#plot csv_file using 2:8:($8 < 1 ? 0 : 1) with linespoints palette pt 5 lw 2 title "internet connect failures", \
#     csv_file using 2:4 with linespoints lc rgb "forest-green" pt 5 lw 2 title "connect successes"
##plot csv_file using 2:8 with linespoints lc rgb "red" pt 5 lw 2 title "internet failure", \
##     csv_file using 2:4 with linespoints lc rgb "red" pt 5 lw 2 dashtype 3 title "wifi failure", \
##     csv_file using 2:4 with linespoints lc rgb "forest-green" pt 5 lw 2 title "connect success"

if ( bargraph_plot ) {
    set style fill solid 0.5 border lt -1
    #set boxwidth 2 relative
    set boxwidth -2
    set grid ytics
    plot csv_file using 2:8 with boxes axes x1y2 lc rgb "red" lw 1 title "internet failure", \
         '' using 2:6 with boxes axes x1y2 lc rgb "blue" lw 1 title "wifi failure", \
         '' using 2:4 with linespoints lc rgb "forest-green" pt 5 lw 2 title "success",
} else {
    #plot csv_file using 2:4 with linespoints lc rgb "forest-green" pt 5 lw 1 title "connect success", \
          
    plot csv_file using 2:8 with linespoints lc rgb "red" pt 5 lw 1 title "internet failure", \
         '' using 2:6 with linespoints lc rgb "blue" pt 5 lw 1 title "wifi failure"
}
pause -1 "Press ENTER to exit the plot? "
