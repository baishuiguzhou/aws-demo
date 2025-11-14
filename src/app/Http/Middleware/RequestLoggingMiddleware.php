<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class RequestLoggingMiddleware
{
    public function handle(Request $request, Closure $next)
    {
        $start = microtime(true);
        $response = $next($request);
        $durationMs = (microtime(true) - $start) * 1000;

        $payload = [
            'message' => 'request_access_log',
            'method' => $request->getMethod(),
            'path' => $request->getPathInfo(),
            'status' => $response->getStatusCode(),
            'ip' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'duration_ms' => round($durationMs, 2),
            'trace_id' => $request->header('X-Amzn-Trace-Id', ''),
            'time' => now()->toIso8601String(),
        ];

        Log::info(json_encode($payload, JSON_UNESCAPED_UNICODE));

        return $response;
    }
}
