# Check for dnsperf
if ! command -v dnsperf &> /dev/null; then
        echo "Error: dnsperf is not installed. Please install it before running this script."
        exit 1
fi

# Usage function
usage() {
        echo "Usage: $0 <duration_minutes> <dns_server_ip>"
        echo ""
        echo "This script generates DNS flood requests using the dnsperf utility."
        echo "It targets a destination DNS server with random requests from files in the"
        echo "./dnsflood-rndrecs/ folder. Useful for performance testing or mining Pi-hole"
        echo "with random data."
        echo ""
        echo "Options:"
        echo "  -h, --help    Show this help message and exit"
        echo ""
        echo "Example:"
        echo "  $0 60 192.168.1.225"
}

# Parse arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
        exit 0
fi

if [[ $# -ne 2 ]]; then
        usage
        exit 1
fi

runtime=$1" minute"
endtime=$(date -ud "$runtime" +%s)
MINWAIT=5
MAXWAIT=120
MINEXEC=5
MAXEXEC=60
MINFILE=1
MAXFILE=100

while [$(date -u +%s) -le $endtime]
do
        echo "Time Now: $(date +%H:%M:%S)"

        dnsperf -l $((MINEXEC+RANDOM % (MAXEXEC-MINEXEC))) \
                -s $2 -Q 5 \
                -d ./dnsflood-rndrecs/rndrecs$((MINFILE+RANDOM % (MAXFILE-MINFILE))).txt

        randomsleep=$((MINWAIT+RANDOM % (MAXWAIT-MINWAIT)))
        echo "sleeping randomly: $randomsleep"
        sleep $randomsleep
done
