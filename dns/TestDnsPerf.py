import argparse
import time
import dns.resolver


def main(dns_servers, domains, num_tests):
    # Loop through each DNS server and domain and test its performance
    for server in dns_servers:
        # Create a DNS resolver object and set the server
        resolver = dns.resolver.Resolver()
        if server != '':
            resolver.nameservers = [server]

        # Record the time taken for all queries to this server
        total_time_server = 0
        server_name = server if server != "" else "Default"
        print(f'DNS Server: {server_name}')

        # Loop through each domain and perform multiple queries
        for domain in domains:
            # Record the time taken for multiple queries to this domain
            total_time_domain = 0
            for i in range(num_tests):
                start_time = time.time()
                answers = resolver.resolve(domain, 'A')
                end_time = time.time()
                query_time = end_time - start_time
                total_time_domain += query_time
            avg_time_domain = total_time_domain / num_tests

            # Add the average time for this domain to the total time for this server
            total_time_server += avg_time_domain

            # Print the results for this domain
            print(f'\t{server_name}: Average query time for {domain} = {avg_time_domain:.3f} seconds')

        # Calculate the average time per server and print the results
        avg_time_server = total_time_server / len(domains)
        print(f'{server_name}: Average query time per server = {avg_time_server:.3f} seconds\n')


if __name__ == '__main__':
  
    # Define the default values for the command-line arguments
    default_dns_servers = ['8.8.8.8', '1.1.1.1', '192.168.1.1', '']
    default_domains = ['example.com', 'google.com', 'facebook.com']
    default_num_tests = 5

    # Define the command-line arguments and their default values
    parser = argparse.ArgumentParser(description='Test the performance of DNS queries to a group of predefined servers')
    parser.add_argument('--dns-servers', nargs='+', default=default_dns_servers, help='The DNS servers to test')
    parser.add_argument('--domains', nargs='+', default=default_domains, help='The domains to query')
    parser.add_argument('--num-tests', type=int, default=default_num_tests, help='The number of times to test each server for each domain')

    # Parse the command-line arguments
    args = parser.parse_args()



    # Call the main function with the command-line arguments
    main(args.dns_servers, args.domains, args.num_tests)
