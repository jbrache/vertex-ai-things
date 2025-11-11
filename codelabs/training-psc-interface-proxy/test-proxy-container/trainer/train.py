import argparse
import traceback
import logging
import requests
# import socket
import sys
import time
import os

def parse_args():
    """Parses command-line arguments.

    Returns:
        Dictionary of arguments.
    """
    parser = argparse.ArgumentParser()

    parser.add_argument('--log-level', help='Logging level.', choices=['DEBUG', 'ERROR', 'FATAL', 'INFO', 'WARN'], default='INFO')
    parser.add_argument('--sleep', help='Amount of time in seconds to sleep.', type=str, default='600s')
    parsed, unknown = parser.parse_known_args()
    return parsed, unknown

def make_api_request(url: str, proxy_vm_ip: str, proxy_vm_port: str):
    """
    Makes a GET request to a non-rfc1918 API and saves the response.

    Args:
        url: The URL of the API to send the request to.
    """

    try:
        # response = requests.get(url)
        proxy_server = f"http://proxy-vm.demo.com:8888" # replace with you VM's IP and proxy port.

        proxies = {
          "http": proxy_server,
          "https": proxy_server,
        }

        response = requests.get(url, proxies=proxies)
        logging.info(response.text)

        response.raise_for_status()  # Raise an exception for bad status codes
        logging.info(f"Successfully fetched data from {url}")
    except requests.exceptions.RequestException as e:
        logging.error(f"An error occurred: {e}")
        raise e

if __name__ == '__main__':
    arguments, unknown_args = parse_args()
    # Configure logging to print clearly to the console
    logging.basicConfig(
        level=arguments.log_level,
        format='%(levelname)s: %(message)s',
        stream=sys.stdout
    )

    if arguments.sleep[-1] == "s":
        sleep = int(arguments.sleep[:-1])
    else:
        sleep = int(arguments.sleep)

    url_to_test = os.environ.get('NONRFC_URL', "http://class-e-vm.demo.com")
    proxy_vm_ip = os.environ.get('PROXY_VM_IP', "proxy-vm.demo.com")
    proxy_vm_port = os.environ.get('PROXY_VM_PORT', "8888")

    logging.info(f"url_to_test: {url_to_test}")
    logging.info(f"proxy_vm_ip: {proxy_vm_ip}")
    logging.info(f"proxy_vm_port: {proxy_vm_port}")
    try:
        make_api_request(url_to_test, proxy_vm_ip, proxy_vm_port)
    except Exception as e:
        logging.error(traceback.format_exc())

    # Sleeping to connect the web interactive shell
    logging.info(f'Sleeping for {sleep} seconds...')
    time.sleep(sleep)
