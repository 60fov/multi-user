const std = @import("std");

pub const RateLimiter = struct {
    ms: i64,
    now: i64,
    last: i64,
    accum: i64,

    pub fn init(rate: i64) RateLimiter {
        return RateLimiter{
            .ms = @divTrunc(std.time.us_per_s, rate),
            .now = std.time.microTimestamp(),
            .last = std.time.microTimestamp(),
            .accum = 0,
        };
    }

    pub fn flushAccumulator(self: *RateLimiter) u32 {
        self.update();

        var step_count: u32 = 0;
        // TODO death spiral if update func takes longer than ms
        while (self.accum >= self.ms) {
            step_count += 1;
            self.accum -= self.ms;
        }
        return step_count;
    }

    // pub fn step(self: *RateLimiter) bool {
    //     const has_cycles = self.accum >= self.ms;
    //     self.accum -= self.ms;
    //     return has_cycles;
    // }

    pub fn call(self: *RateLimiter, func: *const fn (i64) void) void {
        self.update();

        // TODO death spiral if update func takes longer than ms
        while (self.accum >= self.ms) {
            func(self.ms);
            self.accum -= self.ms;
        }
    }

    fn update(self: *RateLimiter) void {
        self.now = std.time.microTimestamp();
        self.accum += self.now - self.last;
        self.last = self.now;
    }
};
