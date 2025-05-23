# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import os

from argparse import ArgumentParser

def check_enum(pid):
    command = f'lsusb | grep -i {pid}'
    if(os.system(command) == 0):
        print("USB is properly enumerated")
        return True
    else:
        print("USB enumeration failed!")
        return False

if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("--pid", required=True)
    args = parser.parse_args()
    if check_enum(args.pid):
        print("[PASS] USB Device Enumeration in {} is successful".format(args.pid))
        print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=usbenum RESULT=pass>")
    else:
        print("[FAIL] USB Device Enumeration in {} has failed".format(args.pid))
        print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=usbenum RESULT=fail>")
