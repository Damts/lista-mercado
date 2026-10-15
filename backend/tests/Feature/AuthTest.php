<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_register_and_password_is_hashed(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Damts',
            'email' => 'damts@example.com',
            'password' => 'secret-password',
            'password_confirmation' => 'secret-password',
        ]);

        $response->assertCreated()
            ->assertJsonStructure(['data' => ['user' => ['id', 'name', 'email'], 'token']]);

        $user = User::where('email', 'damts@example.com')->firstOrFail();
        $this->assertTrue(Hash::check('secret-password', $user->password));
        $this->assertNotSame('secret-password', $user->password);
        $token = $response->json('data.token');

        $this->withToken($token)
            ->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.user.email', 'damts@example.com');
    }

    public function test_user_can_login_and_read_its_session(): void
    {
        $user = User::factory()->create([
            'email' => 'damts@example.com',
            'password' => 'secret-password',
        ]);

        $login = $this->postJson('/api/v1/auth/login', [
            'email' => 'damts@example.com',
            'password' => 'secret-password',
        ]);

        $login->assertOk()
            ->assertJsonStructure(['data' => ['user' => ['id', 'name', 'email'], 'token']]);

        $token = $login->json('data.token');

        $this->withToken($token)
            ->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.user.email', 'damts@example.com');

        $this->assertDatabaseHas('personal_access_tokens', [
            'tokenable_id' => $user->id,
            'tokenable_type' => User::class,
        ]);
    }

    public function test_invalid_login_is_rejected_without_leaking_credentials(): void
    {
        User::factory()->create([
            'email' => 'damts@example.com',
            'password' => 'secret-password',
        ]);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'damts@example.com',
            'password' => 'wrong-password',
        ])
            ->assertUnauthorized()
            ->assertJsonStructure(['message', 'type']);
    }

    public function test_logout_revokes_only_the_current_token(): void
    {
        $user = User::factory()->create();
        $firstToken = $user->createToken('first')->plainTextToken;
        $secondToken = $user->createToken('second')->plainTextToken;

        $this->withToken($firstToken)
            ->postJson('/api/v1/auth/logout')
            ->assertNoContent();

        $this->assertDatabaseCount('personal_access_tokens', 1);
        $this->app['auth']->forgetGuards();
        $this->withToken($firstToken)->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->app['auth']->forgetGuards();
        $this->withToken($secondToken)->getJson('/api/v1/auth/me')->assertOk();
    }
}
