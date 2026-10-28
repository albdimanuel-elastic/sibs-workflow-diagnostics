#!/usr/bin/env python3
"""Pin every core at once so host CPU crosses 90% on the next sample.

Run it on the Linux host that has Elastic Agent, not on the laptop.
The Security rule checks every minute and fires when any sample in that minute
reaches 0.9. The burn starts at full speed so that sample exists immediately.
"""

import argparse
import os
import signal
import sys
import time
from multiprocessing import Process, get_context

PIDFILE = "/tmp/sibs-cpu-load.pid"
NOT_EDR = "cpu-load-other"
EDR = "elastic-endpoin"
# One core = duty 1.0. Stay under 0.70 so Elastic Agent does not kill the process.
ENDPOINT_DUTY = 0.65
HOST_FRACTION = 0.93
OTHER_DUTY_CAP = 0.55


def set_comm(name: str) -> None:
    import ctypes

    libc = ctypes.CDLL(None)
    # PR_SET_NAME. Linux comm is 15 characters plus a trailing NUL.
    encoded = name.encode("ascii")[:15]
    if libc.prctl(15, encoded, 0, 0, 0) != 0:
        raise OSError(f"could not set process name to {name}")


def burn(name: str, stop_at: float, duty: float) -> None:
    import ctypes

    set_comm(name)
    libc = ctypes.CDLL(None)
    # PR_SET_PDEATHSIG: stop if the parent exits.
    libc.prctl(1, signal.SIGTERM, 0, 0, 0)
    slice_s = 0.1
    busy = slice_s * duty
    idle = slice_s - busy
    while time.time() < stop_at:
        if os.getppid() == 1:
            return
        end = time.perf_counter() + busy
        while time.perf_counter() < end:
            pass
        if idle > 0:
            time.sleep(idle)


def mix_plan(cores: int) -> list[tuple[str, float]]:
    """elastic-endpoin is the busiest process, under 70% of one core.

    The other work uses different process names, each smaller than endpoint,
    and the duties add up to about 93% of the machine.
    """
    remaining = HOST_FRACTION * cores - ENDPOINT_DUTY
    if remaining <= 0.05:
        raise SystemExit("This host has too few cores for endpoint under 70% and the machine over 90%.")
    workers = [(EDR, ENDPOINT_DUTY)]
    index = 1
    while remaining > 0.02:
        duty = min(OTHER_DUTY_CAP, remaining)
        workers.append((f"cpu-other-{index:02d}", round(duty, 2)))
        remaining -= duty
        index += 1
    return workers


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate host CPU load under a chosen process name.")
    parser.add_argument("--comm", choices=[NOT_EDR, EDR])
    parser.add_argument("--mix", action="store_true", help="Endpoint under 70 percent of one core and still the busiest process. Host over 90 percent.")
    parser.add_argument("--seconds", type=int, default=180, help="How long to hold the load. Default: 180.")
    parser.add_argument("--duty", type=float, default=1.0, help="Fraction of each core to burn. Default: 1.0.")
    args = parser.parse_args()
    if args.mix == (args.comm is not None):
        print("Pass either --mix or --comm.", file=sys.stderr)
        return 1

    if sys.platform != "linux":
        print("Run this on the Linux host where Elastic Agent is installed.", file=sys.stderr)
        return 1
    if not args.mix and not 0.5 <= args.duty <= 1:
        print("--duty must be between 0.5 and 1.", file=sys.stderr)
        return 1
    if args.seconds < 70:
        print("--seconds must be at least 70 so the 1-minute rule sees the spike.", file=sys.stderr)
        return 1

    cores = os.cpu_count() or 1
    plan = mix_plan(cores) if args.mix else [(args.comm, args.duty) for _ in range(cores)]
    # Over SSH this process is already the session leader, and setpgrp() then
    # returns EPERM. The current group is the one the workers will inherit.
    try:
        os.setpgrp()
    except PermissionError:
        pass
    pgid = os.getpgrp()
    with open(PIDFILE, "w", encoding="utf-8") as handle:
        handle.write(str(pgid))

    stop_at = time.time() + args.seconds
    context = get_context("fork")
    workers = [context.Process(target=burn, args=(name, stop_at, duty)) for name, duty in plan]

    def stop(_signum=None, _frame=None) -> None:
        for worker in workers:
            if worker.is_alive():
                worker.terminate()
        for worker in workers:
            worker.join(timeout=2)
        try:
            os.remove(PIDFILE)
        except FileNotFoundError:
            pass
        raise SystemExit(0)

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    busiest = max(plan, key=lambda item: item[1])
    host_pct = 100 * sum(duty for _, duty in plan) / cores
    print(f"Host cores: {cores}")
    print(f"Target host CPU: about {host_pct:.0f}% for {args.seconds} seconds")
    print(f"Busiest process: {busiest[0]} at {busiest[1]:.0%} of one core")
    for name, duty in plan:
        print(f"  {name}: {duty:.0%} of one core")
    if args.mix:
        print("elastic-endpoin stays under 70% of one core, so Elastic Agent should not kill it.")
        print("It is still the busiest process, so the skill treats Elastic Defend as the cause.")
        print("Host CPU stays above 90%, so the rule can fire and request diagnostics.")
    elif args.comm == EDR:
        print("This name is Elastic Defend. Linux shows elastic-endpoint as elastic-endpoin.")
        print("The skill will treat Defend as the cause and request Fleet diagnostics.")
    else:
        print("This name is not Elastic Defend and not elastic-agent.")
        print("The skill will open a case and will not request diagnostics.")
    print("The Security rule checks every minute and fires when any sample reaches 90%.")
    print(f"Stop early with: kill -TERM -{pgid}")

    for worker in workers:
        worker.start()
    for worker in workers:
        worker.join()
    try:
        os.remove(PIDFILE)
    except FileNotFoundError:
        pass
    print("CPU load finished.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
