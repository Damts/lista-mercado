<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Models\User;
use App\Models\Pessoa;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function register(RegisterRequest $request): JsonResponse
    {
        $user = DB::transaction(function () use ($request): User {
            $user = User::create($request->validated());
            Pessoa::create(['user_id' => $user->id]);

            return $user;
        });
        $token = $user->createToken('auth')->plainTextToken;

        return response()->json(['data' => [
            'user' => $this->userData($user),
            'token' => $token,
        ]], 201);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $credentials = $request->validated();
        $user = User::where('email', $credentials['email'])->first();

        if ($user === null || ! Hash::check($credentials['password'], $user->password)) {
            return response()->json([
                'message' => 'Credenciais inválidas.',
                'type' => 'authentication_failed',
            ], 401);
        }

        $token = $user->createToken('auth')->plainTextToken;

        // Garante que o usuário tenha um registro de Pessoa (evita null em rotas de casa/convite).
        $user->pessoa()->firstOrCreate([]);

        return response()->json(['data' => [
            'user' => $this->userData($user),
            'token' => $token,
        ]]);
    }

    public function me(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        return response()->json(['data' => ['user' => $this->userData($user)]]);
    }

    public function logout(Request $request): \Illuminate\Http\Response
    {
        $request->user()->currentAccessToken()->delete();

        return response()->noContent();
    }

    /** @return array{id: int, name: string, email: string} */
    private function userData(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
        ];
    }
}
