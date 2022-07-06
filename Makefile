# Makefile for moniconn.
SHELL='bash'

REQUIRED :=./moniconn.sh ./plot-conn.gp 
# Macros
define hdr
        @printf '\033[35;1m\n'
        @printf '=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n'
        @printf '=-=-= Target: %s %s\n' "$1"
        @printf '=-=-= Date: %s %s\n' "$(shell date)"
        @printf '=-=-= Directory: %s %s\n' "$$(pwd)"
        @printf '=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-='
        @printf '\033[0m\n'
endef

.PHONY: interval
interval: | $(REQUIRED)  ## Make a custom interval report. Must set START and STOP times. Example: make interval START=13:00 STOP=17:00
	$(call hdr,"$@-$(START)-to-$(STOP)")
	BASE="moniconn-$(START)-to-$(STOP)" && \
	CSV="$$BASE-$@.csv" && \
	LOG="$$BASE-$@.log" && \
	VERBOSE=2 START=$(START) STOP=$(STOP) CSV="$$CSV" \
		./moniconn.sh 2>&1 | tee -i -a "$$LOG" && \
	if [ -f "$$CSV" ] ; then ./plot-conn.gp "$$CSV" ; fi

.PHONY: hour
hour: | $(REQUIRED)  ## Make an hourly report starting at the beginning of the next hour and display plot when done.
	$(call hdr,"$@")
	BASE="moniconn-$$(date -d '+1 hour' +%F)" && \
	CSV="$$BASE-$@.csv" && \
	LOG="$$BASE-$@.log" && \
	START=$$(date +'%Y-%m-%dT%H:%M:00' -d '+1 hour') && \
	VERBOSE=2 START="$$START" STOP='1 hour' CSV="$$CSV" \
		./moniconn.sh 2>&1 | tee -i -a "$$LOG" && \
	if [ -f "$$CSV" ] ; then ./plot-conn.gp "$$CSV" ; fi

.PHONY: hour-now
hour-now: | $(REQUIRED)  ## Make an hourly report starting now and display plot when done.
	$(call hdr,"$@")
	BASE="moniconn-$$(date -d '+1 hour' +%F)" && \
	CSV="$$BASE-$@.csv" && \
	LOG="$$BASE-$@.log" && \
	VERBOSE=2 STOP='1 hour' CSV="$$CSV" \
		./moniconn.sh 2>&1 | tee -i -a "$$LOG" && \
	if [ -f "$$CSV" ] ; then ./plot-conn.gp "$$CSV" ; fi

.PHONY: day
day: | $(REQUIRED)  ## Make a daily report for the next full day and display plot when done.
	$(call hdr,"$@")
	BASE="moniconn-$$(date -d '+1 $@' +%F)" && \
	LOG="$$BASE-$@.log" && \
	CSV="$$BASE-$@.csv" && \
	VERBOSE=2 START="23:59" STOP='1 day' CSV="$$CSV" \
	./moniconn.sh 2>&1 | tee -i -a "$$LOG"  && \
	if [ -f "$$CSV" ] ; then ./plot-conn.gp "$$CSV" ; fi

.PHONY: week
week: | $(REQUIRED)  ## Make a weekly report starting the next full day and display plot when done.
	$(call hdr,"$@")
	BASE="moniconn-$$(date -d '+1 day' +%F)" && \
	CSV="$$BASE-$@.csv" && \
	LOG="$$BASE-$@.log" && \
	VERBOSE=2 START="23:59" STOP='1 week' CSV="$$CSV" \
		./moniconn.sh 2>&1 | tee -i -a "$$LOG" && \
	if [ -f "$$CSV" ] ; then ./plot-conn.gp "$$CSV" ; fi


.PHONY: help
help:  ## this help message
	$(call hdr,"$@")
	@printf "\n\033[35;1m%s\n" "Targets"
	@grep -E '^[ ]*[^:]*[ ]*:.*##' $(MAKEFILE_LIST) 2>/dev/null | \
		grep -E -v '^ *#' | \
	        grep -E -v "egrep|sort|sed|MAKEFILE" | \
		sed -e 's/: .*##/##/' -e 's/^[^:#]*://' | \
		column -t -s '##' | \
		sort -f | \
		sed -e 's@^@   @'
#	@printf "\n\033[35;1m%s\n" "Variables"
#	@printf '    DST  : %s\n' $(DST)
#	@printf '    PORT : %s\n' $(PORT)
	@printf "\033[0m\n"
