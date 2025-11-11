import argparse
import logging
import sys
import os
import time
import json

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

if __name__ == '__main__':
    """Entry point"""
    arguments, unknown_args = parse_args()
    logging.basicConfig(level=arguments.log_level)

    if arguments.sleep[-1] == "s":
        sleep = int(arguments.sleep[:-1])
    else:
        sleep = int(arguments.sleep)

    # Sleeping 600 seconds to connect the web shell
    logging.info(f'Sleeping for {sleep} seconds...')
    time.sleep(sleep)
