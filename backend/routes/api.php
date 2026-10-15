<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CasaController;
use App\Http\Controllers\Api\V1\CasaContextController;
use App\Http\Controllers\Api\V1\ItemController;
use App\Http\Controllers\Api\V1\ConviteController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::prefix('auth')->group(function (): void {
        Route::post('register', [AuthController::class, 'register']);
        Route::post('login', [AuthController::class, 'login']);

        Route::middleware('auth:sanctum')->group(function (): void {
            Route::get('me', [AuthController::class, 'me']);
            Route::post('logout', [AuthController::class, 'logout']);
        });
    });

    Route::middleware('auth:sanctum')->group(function (): void {
        Route::get('casas', [CasaController::class, 'index']);
        Route::get('casa-atual', [CasaContextController::class, 'show'])
            ->middleware('casa.context');
        Route::get('itens', [ItemController::class, 'index'])
            ->middleware('casa.context');
        Route::post('itens', [ItemController::class, 'store'])
            ->middleware('casa.context');
        Route::get('itens/{item}', [ItemController::class, 'show'])
            ->middleware('casa.context');
        Route::patch('itens/{item}', [ItemController::class, 'update'])
            ->middleware('casa.context');
        Route::delete('itens/{item}', [ItemController::class, 'destroy'])
            ->middleware('casa.context');
        Route::post('casas', [CasaController::class, 'store']);
        Route::get('casas/{casa}', [CasaController::class, 'show']);
        Route::post('casas/{casa}/convites', [ConviteController::class, 'store']);
        Route::post('casas/{casa}/convites/{convite}/revogar', [ConviteController::class, 'revoke']);
        Route::post('convites/entrar', [ConviteController::class, 'join']);
    });
});
