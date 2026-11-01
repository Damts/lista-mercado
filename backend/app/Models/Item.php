<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Item extends Model
{
    protected $table = 'itens';

    protected $fillable = ['casa_id', 'lista_id', 'nome', 'nome_normalizado', 'quantidade', 'medida', 'preco', 'comprado'];

    protected function casts(): array
    {
        return [
            'quantidade' => 'integer',
            'medida' => 'string',
            'preco' => 'decimal:2',
            'comprado' => 'boolean',
        ];
    }

    public function casa(): BelongsTo
    {
        return $this->belongsTo(Casa::class);
    }

    public function lista(): BelongsTo
    {
        return $this->belongsTo(Lista::class);
    }
}
