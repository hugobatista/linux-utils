
# DNS Utilities

This folder contains scripts and tools for DNS testing, flooding, and performance analysis.

## dnsflood.sh
Floods a target DNS server with random requests using the dnsperf utility. Useful for stress-testing DNS servers or feeding Pi-hole with random data.

- Uses request files from `dnsflood-rndrecs/`.
- Randomizes request files and timing.
+- Example:
	```bash
	./dnsflood.sh 60 192.168.1.1
	```
	(Floods for 60 minutes to 192.168.1.1)

### Download and Execute Remotely with curl

You can download and run `dnsflood.sh` directly on a remote machine using curl:

+```bash
curl -O http://go.hugobatista.com/gh/linux-utils/dns/dnsflood/dnsflood.sh
chmod +x dnsflood.sh
./dnsflood.sh 60 192.168.1.1
```

Or, to run it directly without saving:

```bash
curl http://go.hugobatista.com/gh/linux-utils/dns/dnsflood/dnsflood.sh | bash -s -- 60 192.168.1.1
```

## TestDnsPerf.py
Python script to benchmark DNS query performance against multiple servers and domains.

- Usage:
	```bash
	python3 TestDnsPerf.py --dns-servers 8.8.8.8 1.1.1.1 --domains example.com google.com --num-tests 5
	```
- Default servers: 8.8.8.8, 1.1.1.1, 192.168.1.1, system default
- Default domains: example.com, google.com, facebook.com
- Reports average query time per domain and per server.

## Folder Structure
- `dnsflood/` — DNS flooding scripts and random record files
- `TestDnsPerf.py` — DNS performance testing script
- `readme.md` — This documentation

## Requirements
- dnsperf (for dnsflood.sh)
- Python 3 and dnspython (for TestDnsPerf.py)

## See Also
- Use these tools to test, benchmark, or stress DNS servers, including Pi-hole setups.
- For more details, see comments in each script.

