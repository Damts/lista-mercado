<?php

namespace Tests\Feature;

use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ListaMensalTest extends TestCase
{
    use RefreshDatabase;

    public function test_opening_a_house_creates_and_returns_its_current_month_list(): void
    {
        $token = $this->register('owner@example.com');
        $houseId = $this->createHouse($token, 'Casa');

        $this->travelTo(CarbonImmutable::parse('2026-10-31 23:00:00', 'America/Sao_Paulo'));
        $response = $this->asHouse($token, $houseId)->getJson('/api/v1/casas/'.$houseId.'/listas')->assertOk();
        $this->travelBack();

        $response->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.casa_id', $houseId)
            ->assertJsonPath('data.0.ano', 2026)
            ->assertJsonPath('data.0.mes', 10)
            ->assertJsonPath('data.0.fechado_em', null);
    }

    public function test_items_are_isolated_by_month_and_house(): void
    {
        $firstToken = $this->register('first@example.com');
        $firstHouse = $this->createHouse($firstToken, 'Primeira');
        $secondToken = $this->register('second@example.com');
        $secondHouse = $this->createHouse($secondToken, 'Segunda');

        $firstList = $this->asHouse($firstToken, $firstHouse)->getJson('/api/v1/casas/'.$firstHouse.'/listas')->json('data.0.id');
        $secondList = $this->asHouse($secondToken, $secondHouse)->getJson('/api/v1/casas/'.$secondHouse.'/listas')->json('data.0.id');
        $this->asHouse($firstToken, $firstHouse)->postJson('/api/v1/itens', ['nome' => 'Arroz', 'quantidade' => 1])->assertCreated();

        $this->asHouse($firstToken, $firstHouse)->getJson('/api/v1/listas/'.$firstList.'/itens')
            ->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.nome', 'Arroz');
        $this->asHouse($secondToken, $secondHouse)->getJson('/api/v1/listas/'.$firstList.'/itens')->assertNotFound();
        $this->asHouse($secondToken, $secondHouse)->getJson('/api/v1/listas/'.$secondList.'/itens')
            ->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_creating_next_month_closes_previous_and_blocks_mutation(): void
    {
        $token = $this->register('owner@example.com');
        $houseId = $this->createHouse($token, 'Casa');

        $this->travelTo(CarbonImmutable::parse('2026-10-31 23:00:00', 'America/Sao_Paulo'));
        $october = $this->asHouse($token, $houseId)->getJson('/api/v1/casas/'.$houseId.'/listas')->json('data.0.id');
        $itemId = $this->asHouse($token, $houseId)->postJson('/api/v1/itens', ['nome' => 'Leite', 'quantidade' => 1])->json('data.id');
        $this->travelTo(CarbonImmutable::parse('2026-11-01 00:00:00', 'America/Sao_Paulo'));
        $this->asHouse($token, $houseId)->postJson('/api/v1/casas/'.$houseId.'/listas')->assertCreated();
        $this->asHouse($token, $houseId)->patchJson('/api/v1/itens/'.$itemId, ['comprado' => true])
            ->assertStatus(409)->assertJsonPath('error_code', 'lista_fechada');
        $this->assertDatabaseHas('listas', ['id' => $october]);
        $this->travelBack();
    }

    private function asHouse(string $token, int $houseId): self
    {
        return $this->withToken($token)->withHeader('X-Casa-ID', (string) $houseId);
    }

    private function createHouse(string $token, string $name): int
    {
        return $this->withToken($token)->postJson('/api/v1/casas', ['nome' => $name])->json('data.id');
    }

    private function register(string $email): string
    {
        return $this->postJson('/api/v1/auth/register', [
            'name' => 'Person', 'email' => $email,
            'password' => 'secret-password', 'password_confirmation' => 'secret-password',
        ])->json('data.token');
    }
}
