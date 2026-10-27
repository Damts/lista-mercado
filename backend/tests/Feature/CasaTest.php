<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CasaTest extends TestCase
{
    use RefreshDatabase;

    public function test_account_can_create_and_list_only_its_houses(): void
    {
        $token = $this->register('owner@example.com');

        $first = $this->withToken($token)->postJson('/api/v1/casas', [
            'nome' => 'Casa principal',
        ])->assertCreated();

        $second = $this->withToken($token)->postJson('/api/v1/casas', [
            'nome' => 'Casa de praia',
        ])->assertCreated();

        $this->withToken($token)
            ->getJson('/api/v1/casas')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.nome', 'Casa principal')
            ->assertJsonPath('data.1.nome', 'Casa de praia');

        $this->withToken($token)
            ->getJson('/api/v1/casas/'.$first->json('data.id'))
            ->assertOk()
            ->assertJsonPath('data.nome', 'Casa principal');

        $this->assertNotSame($first->json('data.id'), $second->json('data.id'));
    }

    public function test_house_creation_requires_authentication(): void
    {
        $this->postJson('/api/v1/casas', ['nome' => 'Sem sessão'])
            ->assertUnauthorized();
    }

    public function test_validation_rejects_empty_or_oversized_house_name(): void
    {
        $token = $this->register('owner@example.com');

        $this->withToken($token)
            ->postJson('/api/v1/casas', ['nome' => ''])
            ->assertUnprocessable();

        $this->withToken($token)
            ->postJson('/api/v1/casas', ['nome' => str_repeat('a', 121)])
            ->assertUnprocessable();
    }

    public function test_house_contract_returns_an_explicit_not_found_for_another_users_house(): void
    {
        $ownerToken = $this->register('owner@example.com');
        $houseId = $this->createHouse($ownerToken, 'Privada');
        $outsiderToken = $this->register('outsider@example.com');

        $this->app['auth']->forgetGuards();

        $this->withToken($outsiderToken)
            ->getJson('/api/v1/casas/'.$houseId)
            ->assertNotFound()
            ->assertJsonPath('error_code', 'house_not_found')
            ->assertJsonMissingPath('data');
    }

    private function createHouse(string $token, string $name): int
    {
        return $this->withToken($token)
            ->postJson('/api/v1/casas', ['nome' => $name])
            ->json('data.id');
    }

    private function register(string $email): string
    {
        return $this->postJson('/api/v1/auth/register', [
            'name' => 'Owner',
            'email' => $email,
            'password' => 'secret-password',
            'password_confirmation' => 'secret-password',
        ])->json('data.token');
    }
}
