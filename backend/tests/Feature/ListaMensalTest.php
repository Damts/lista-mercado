<?php

namespace Tests\Feature;

use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
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

    public function test_copying_last_non_empty_month_creates_clean_item_snapshots(): void
    {
        $token = $this->register('copy-owner@example.com');
        $houseId = $this->createHouse($token, 'Casa da cópia');

        $this->travelTo(CarbonImmutable::parse('2026-10-31 23:00:00', 'America/Sao_Paulo'));
        $originId = $this->asHouse($token, $houseId)->getJson('/api/v1/casas/'.$houseId.'/listas')->json('data.0.id');
        foreach ([['Arroz', 2, 'kg', '18.90'], ['Leite', 3, 'l', '5.49'], ['Café', 1, 'un', '22.00'], ['Macarrão', 2, 'un', '7.50'], ['Sal', 1, 'kg', null]] as [$nome, $quantidade, $medida, $preco]) {
            $this->asHouse($token, $houseId)->postJson('/api/v1/itens', compact('nome', 'quantidade', 'medida', 'preco'))->assertCreated();
        }

        $this->travelTo(CarbonImmutable::parse('2026-11-01 00:00:00', 'America/Sao_Paulo'));
        $destinationId = $this->asHouse($token, $houseId)->postJson('/api/v1/casas/'.$houseId.'/listas')->json('data.id');

        $this->asHouse($token, $houseId)
            ->postJson('/api/v1/listas/'.$destinationId.'/copiar-de/'.$originId)
            ->assertNoContent();

        $this->assertDatabaseCount('itens', 10);
        $this->assertDatabaseHas('itens', [
            'lista_id' => $destinationId,
            'nome' => 'Arroz',
            'quantidade' => 2,
            'medida' => 'kg',
            'preco' => null,
            'preco_anterior' => '18.90',
            'comprado' => false,
        ]);
        $this->assertDatabaseHas('itens', [
            'lista_id' => $destinationId,
            'nome' => 'Sal',
            'preco' => null,
            'preco_anterior' => null,
            'comprado' => false,
        ]);
        DB::table('itens')->where('lista_id', $originId)->where('nome', 'Arroz')->update(['preco' => '99.99']);
        $this->assertDatabaseHas('itens', ['lista_id' => $destinationId, 'nome' => 'Arroz', 'preco_anterior' => '18.90']);
        $this->travelBack();
    }

    public function test_copy_uses_the_latest_non_empty_list_even_when_intermediate_months_are_empty(): void
    {
        $token = $this->register('skip-month@example.com');
        $houseId = $this->createHouse($token, 'Casa com lacuna');

        $this->travelTo(CarbonImmutable::parse('2026-08-31 23:00:00', 'America/Sao_Paulo'));
        $augustId = $this->asHouse($token, $houseId)->getJson('/api/v1/casas/'.$houseId.'/listas')->json('data.0.id');
        $this->asHouse($token, $houseId)->postJson('/api/v1/itens', ['nome' => 'Feijão', 'quantidade' => 1, 'medida' => 'kg', 'preco' => '8.75'])->assertCreated();

        $this->travelTo(CarbonImmutable::parse('2026-09-01 00:00:00', 'America/Sao_Paulo'));
        $this->asHouse($token, $houseId)->postJson('/api/v1/casas/'.$houseId.'/listas')->assertCreated();
        $this->travelTo(CarbonImmutable::parse('2026-10-01 00:00:00', 'America/Sao_Paulo'));
        $this->asHouse($token, $houseId)->postJson('/api/v1/casas/'.$houseId.'/listas')->assertCreated();
        $this->travelTo(CarbonImmutable::parse('2026-11-01 00:00:00', 'America/Sao_Paulo'));
        $novemberId = $this->asHouse($token, $houseId)->postJson('/api/v1/casas/'.$houseId.'/listas')->json('data.id');

        $this->asHouse($token, $houseId)->postJson('/api/v1/listas/'.$novemberId.'/copiar-de/'.$augustId)->assertNoContent();
        $this->assertDatabaseHas('itens', ['lista_id' => $novemberId, 'nome' => 'Feijão', 'preco_anterior' => '8.75']);
        $this->travelBack();
    }

    public function test_second_copy_returns_conflict_without_duplicate_items_and_foreign_list_is_hidden(): void
    {
        $ownerToken = $this->register('copy-conflict@example.com');
        $ownerHouse = $this->createHouse($ownerToken, 'Casa origem');
        $foreignToken = $this->register('foreign-copy@example.com');
        $foreignHouse = $this->createHouse($foreignToken, 'Casa externa');

        $this->travelTo(CarbonImmutable::parse('2026-10-31 23:00:00', 'America/Sao_Paulo'));
        $originId = $this->asHouse($ownerToken, $ownerHouse)->getJson('/api/v1/casas/'.$ownerHouse.'/listas')->json('data.0.id');
        $foreignOriginId = $this->asHouse($foreignToken, $foreignHouse)->getJson('/api/v1/casas/'.$foreignHouse.'/listas')->json('data.0.id');
        $this->asHouse($ownerToken, $ownerHouse)->postJson('/api/v1/itens', ['nome' => 'Aveia', 'quantidade' => 1])->assertCreated();
        $this->asHouse($foreignToken, $foreignHouse)->postJson('/api/v1/itens', ['nome' => 'Farinha', 'quantidade' => 1])->assertCreated();

        $this->travelTo(CarbonImmutable::parse('2026-11-01 00:00:00', 'America/Sao_Paulo'));
        $destinationId = $this->asHouse($ownerToken, $ownerHouse)->postJson('/api/v1/casas/'.$ownerHouse.'/listas')->json('data.id');
        $this->asHouse($ownerToken, $ownerHouse)->postJson('/api/v1/listas/'.$destinationId.'/copiar-de/'.$originId)->assertNoContent();

        $this->asHouse($ownerToken, $ownerHouse)->postJson('/api/v1/listas/'.$destinationId.'/copiar-de/'.$originId)
            ->assertStatus(409)->assertJsonPath('type', 'conflict')->assertJsonPath('error_code', 'lista_nao_vazia');
        $this->assertDatabaseCount('itens', 3);
        $this->asHouse($ownerToken, $ownerHouse)->postJson('/api/v1/listas/'.$destinationId.'/copiar-de/'.$foreignOriginId)->assertNotFound();
        $this->assertDatabaseCount('itens', 3);
        $this->travelBack();
    }

    public function test_backfill_respects_sao_paulo_timezone_boundary(): void
    {
        // Item criado 31/10 23:00 UTC = 31/10 20:00 SP -> outubro
        $octDate = CarbonImmutable::parse('2026-10-31 23:00:00', 'UTC')->setTimezone('America/Sao_Paulo');
        $this->assertSame(10, $octDate->month);
        $this->assertSame(2026, $octDate->year);

        // Item criado 01/11 00:00 UTC = 31/10 21:00 SP -> outubro (ainda outubro em SP)
        $stillOct = CarbonImmutable::parse('2026-11-01 00:00:00', 'UTC')->setTimezone('America/Sao_Paulo');
        $this->assertSame(10, $stillOct->month);

        // Item criado 01/11 02:59 UTC = 31/10 23:59 SP -> outubro (fronteira)
        $boundary = CarbonImmutable::parse('2026-11-01 02:59:00', 'UTC')->setTimezone('America/Sao_Paulo');
        $this->assertSame(10, $boundary->month);
        $this->assertSame(31, $boundary->day);

        // Item criado 01/11 04:00 UTC = 01/11 01:00 SP -> novembro
        $novDate = CarbonImmutable::parse('2026-11-01 04:00:00', 'UTC')->setTimezone('America/Sao_Paulo');
        $this->assertSame(11, $novDate->month);
        $this->assertSame(2026, $novDate->year);
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
