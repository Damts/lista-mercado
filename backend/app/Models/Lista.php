<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Lista extends Model
{
    protected $table = 'listas';

    protected $fillable = ['casa_id', 'ano', 'mes', 'fechado_em'];

    protected function casts(): array
    {
        return ['ano' => 'integer', 'mes' => 'integer', 'fechado_em' => 'datetime'];
    }

    public function casa(): BelongsTo
    {
        return $this->belongsTo(Casa::class);
    }

    public function itens(): HasMany
    {
        return $this->hasMany(Item::class);
    }
}
