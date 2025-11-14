<?php

use App\Services\AppConfigRepository;
use Illuminate\Support\Facades\Route;

Route::get('/', function (AppConfigRepository $appConfig) {
    return view('welcome', [
        'poperMessage' => $appConfig->getHomepageMessage(),
    ]);
});
