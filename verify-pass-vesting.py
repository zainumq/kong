#!/usr/bin/env python3
"""BscScan verification for the Kong sub-contracts (KongMintPass + 2x KongVesting) via the
Etherscan V2 API (chainid 56), reusing the custom.bscscan connector credential.

Free-plan quirk (proven 18 Nov 2026): checkverifysourcecode is NOT supported
for chain 56 on the free plan, so status is polled via getsourcecode
(SourceCode non-empty = verified).

Usage:
  verify-bscscan.py --status           # check both contracts
  verify-bscscan.py --verify           # submit unverified ones + poll
  verify-bscscan.py --verify token     # only KongToken
  verify-bscscan.py --verify sale      # only KongSale
"""
import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

sys.path.insert(0, "/opt/muse/skills/custom-connector-setup/bin")
from dynamic_credentials import (  # noqa: E402
    DynamicCredentialError,
    read_json_response,
    url_with_surrogate_query_param,
)

API_BASE = "https://api.etherscan.io/v2/api"
CONNECTOR = "custom.bscscan"
ALLOWED_HOSTS = ["api.etherscan.io", "api.bscscan.com"]
CHAINID = "56"

COMPILER_VERSION = "v0.8.24+commit.e11b9ed9"
OPTIMIZER_RUNS = "200"
EVM_VERSION = "cancun"
LICENSE_TYPE_MIT = "3"
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Kong-verify/1.0"
BASE = "/home/hatch/workspace/bonding-curve-design/kong"

CONTRACTS = {
    "pass": {
        "address": "0x615AAaFF423f1005B7bF51e3dEC6BbF5958Af89B",
        "name": "KongMintPass",
        "source": f"{BASE}/flattened/KongMintPass.flattened.sol",
        "args_file": f"{BASE}/flattened/kong-pass-constructor-args-encoded.txt",
    },
    "treasury": {
        "address": "0xd895ca5F431bA80687Bc9bf614EF850472E19f8B",
        "name": "KongVesting",
        "source": f"{BASE}/flattened/KongVesting.flattened.sol",
        "args_file": f"{BASE}/flattened/kong-vesting-constructor-args-encoded.txt",
    },
    "team": {
        "address": "0x11151065995e0B2B6989038181Dd42902ae28078",
        "name": "KongVesting",
        "source": f"{BASE}/flattened/KongVesting.flattened.sol",
        "args_file": f"{BASE}/flattened/kong-vesting-constructor-args-encoded.txt",
    },
}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        raise RuntimeError("redirect refused, verify the endpoint")


def _open(request, timeout=60):
    return urllib.request.build_opener(NoRedirect()).open(request, timeout=timeout)


def _api_url(params):
    query = urllib.parse.urlencode([("chainid", CHAINID)] + list(params.items()))
    return f"{API_BASE}?{query}"


def _get(params, timeout=60):
    url = url_with_surrogate_query_param(
        _api_url(params), CONNECTOR, allowed_hosts=ALLOWED_HOSTS
    )
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_exc = None
    for _ in range(2):
        try:
            with _open(request, timeout=timeout) as response:
                return read_json_response(response)
        except (urllib.error.URLError, TimeoutError) as exc:
            last_exc = exc
            time.sleep(2)
    raise DynamicCredentialError(f"GET failed after retry: {last_exc}")


def _post(form, timeout=120):
    url = url_with_surrogate_query_param(
        _api_url({}), CONNECTOR, allowed_hosts=ALLOWED_HOSTS
    )
    data = urllib.parse.urlencode(form).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={
            "User-Agent": USER_AGENT,
            "Content-Type": "application/x-www-form-urlencoded",
        },
    )
    last_exc = None
    for _ in range(2):
        try:
            with _open(request, timeout=timeout) as response:
                return read_json_response(response)
        except (urllib.error.URLError, TimeoutError) as exc:
            last_exc = exc
            time.sleep(2)
    raise DynamicCredentialError(f"POST failed after retry: {last_exc}")


def is_verified(spec):
    result = _get(
        {"module": "contract", "action": "getsourcecode", "address": spec["address"]}
    )
    if result.get("status") != "1":
        print(f"  status check failed: {result.get('message')} / {result.get('result')}")
        return None
    entries = result.get("result") or []
    source = (entries[0].get("SourceCode") or "") if entries else ""
    return bool(source.strip())


def submit(spec):
    with open(spec["source"], "r", encoding="utf-8") as f:
        source = f.read()
    args = ""
    if spec["args_file"]:
        with open(spec["args_file"], "r", encoding="utf-8") as f:
            args = f.read().strip()
        if args.startswith("0x"):
            args = args[2:]
    form = {
        "module": "contract",
        "action": "verifysourcecode",
        "contractaddress": spec["address"],
        "contractname": spec["name"],
        "compilerversion": COMPILER_VERSION,
        "sourceCode": source,
        "codeformat": "solidity-single-file",
        "constructorArguements": args,  # Etherscan's spelling
        "optimizationUsed": "1",
        "runs": OPTIMIZER_RUNS,
        "licenseType": LICENSE_TYPE_MIT,
        "evmversion": EVM_VERSION,
    }
    result = _post(form)
    print("  submit:", json.dumps(result)[:300])
    if result.get("status") != "1":
        print(f"  SUBMIT FAILED: {result.get('message')} / {result.get('result')}")
        return None
    return result["result"]


def poll_verified(spec, attempts=20, interval=15):
    for i in range(attempts):
        v = is_verified(spec)
        print(f"  [{i + 1}] {'VERIFIED' if v else ('check-failed' if v is None else 'pending')}")
        if v:
            return True
        time.sleep(interval)
    print("  Still not verified after polling.")
    return False


def main():
    parser = argparse.ArgumentParser(description="BscScan verify helper (Kong)")
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--verify", nargs="?", const="both", choices=["both", "pass", "treasury", "team"])
    args = parser.parse_args()
    keys = ["pass", "treasury", "team"] if args.verify in ("both", None) else [args.verify]
    if args.status:
        ok = True
        for k in keys:
            spec = CONTRACTS[k]
            v = is_verified(spec)
            print(f"{spec['name']}: {'VERIFIED' if v else ('UNKNOWN' if v is None else 'NOT VERIFIED')}")
            ok = ok and bool(v)
        sys.exit(0 if ok else 2)
    if args.verify:
        all_ok = True
        for k in keys:
            spec = CONTRACTS[k]
            print(f"== {spec['name']} {spec['address']} ==")
            v = is_verified(spec)
            if v:
                print("  Already verified; nothing to submit.")
                continue
            if v is None:
                print("  Could not check status; aborting submit.")
                all_ok = False
                continue
            guid = submit(spec)
            if guid is None:
                all_ok = False
                continue
            print("  GUID:", guid)
            all_ok = poll_verified(spec) and all_ok
        sys.exit(0 if all_ok else 1)
    parser.print_help()
    sys.exit(2)


if __name__ == "__main__":
    main()
