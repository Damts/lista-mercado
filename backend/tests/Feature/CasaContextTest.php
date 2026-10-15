<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CasaContextTest extends TestCase
{
    use RefreshDatabase;

    public function test_member_can_select_each_house_it_belongs_to(): void
    {
        $ownerToken = $this->register('owner@example.com');
        $firstHouse = $this->createHouse($ownerToken, 'Casa 1');
        $secondHouse = $this->createHouse($ownerToken, 'Casa 2');

        $this->withToken($ownerToken)
            ->withHeader('X-Casa-ID', (string) $firstHouse)
            ->getJson('/api/v1/casa-atual')
            ->assertOk()
            ->assertJsonPath('data.id', $firstHouse)
            ->assertJsonPath('data.nome', 'Casa 1');

        $this->app['auth']->forgetGuards();
        $this->withToken($ownerToken)
            ->withHeader('X-Casa-ID', (string) $secondHouse)
            ->getJson('/api/v1/casa-atual')
            ->assertOk()
            ->assertJsonPath('data.id', $secondHouse)
            ->assertJsonPath('data.nome', 'Casa 2');
    }

    public function test_missing_context_is_a_bad_request(): void
    {
        $token = $this->register('owner@example.com');

        $this->withToken($token)
            ->getJson('/api/v1/casa-atual')
            ->assertBadRequest()
            ->assertJsonPath('type', 'house_context_required');
    }

    public function test_house_from_another_account_is_hidden_as_not_found(): void
    {
        $ownerToken = $this->register('owner@example.com');
        $houseId = $this->createHouse($ownerToken, 'Privada');
        $outsiderToken = $this->register('outsider@example.com');
        $this->app['auth']->forgetGuards();

        $this->withToken($outsiderToken)
            ->withHeader('X-Casa-ID', (string) $houseId)
            ->getJson('/api/v1/casa-atual')
            ->assertNotFound()
            ->assertJsonPath('type', 'not_found');
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
            'name' => 'Person',
            'email' => $email,
            'password' => 'secret-password',
            'password_confirmation' => 'secret-password',
        ])->json('data.token');
    }
}
