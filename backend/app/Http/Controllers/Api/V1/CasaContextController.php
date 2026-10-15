<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Casa;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CasaContextController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        /** @var Casa $casa */
        $casa = $request->attributes->get('casa');

        return response()->json(['data' => $casa->only(['id', 'nome', 'created_at'])]);
    }
}
