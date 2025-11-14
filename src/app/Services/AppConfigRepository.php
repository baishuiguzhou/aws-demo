<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class AppConfigRepository
{
    private const CACHE_TTL_SECONDS = 30;

    private static ?array $cachedConfiguration = null;
    private static int $lastFetchedAt = 0;

    public function __construct(
        private readonly ?string $endpoint = null,
    ) {
    }

    /**
     * Resolve the message that should be rendered on the homepage.
     */
    public function getHomepageMessage(): string
    {
        $config = $this->getConfiguration();
        $envKey = $config['homepage_env'] ?? 'POPER_MESSAGE';

        $message = env($envKey);

        if ($message === null && isset($config['feature_message'])) {
            $message = $config['feature_message'];
        }

        if ($message === null && env('POPER_MESSAGE')) {
            $message = env('POPER_MESSAGE');
        }

        return $message ?? 'Hello from Laravel on ECS';
    }

    /**
     * Retrieve (and lightly cache) the latest AppConfig hosted configuration.
     */
    private function getConfiguration(): array
    {
        $endpoint = $this->endpoint ?? config('services.appconfig.endpoint');

        if (!$endpoint) {
            return [];
        }

        if (
            self::$cachedConfiguration !== null
            && (time() - self::$lastFetchedAt) < self::CACHE_TTL_SECONDS
        ) {
            return self::$cachedConfiguration;
        }

        try {
            $response = Http::timeout(2)->get($endpoint);

            if ($response->successful()) {
                $config = $response->json() ?? [];
                if (is_array($config)) {
                    self::$cachedConfiguration = $config;
                    self::$lastFetchedAt = time();
                    return $config;
                }
            }

            Log::warning('AppConfig response was not successful', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);
        } catch (\Throwable $exception) {
            Log::warning('Failed to fetch AppConfig configuration', [
                'error' => $exception->getMessage(),
            ]);
        }

        return self::$cachedConfiguration ?? [];
    }
}
