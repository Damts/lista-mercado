<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Convite extends Model
{
    protected $fillable = [
        'casa_id',
        'codigo',
        'expira_em',
        'usado_em',
        'revogado_em',
        'usado_por_pessoa_id',
    ];

    protected function casts(): array
    {
        return [
            'expira_em' => 'datetime',
            'usado_em' => 'datetime',
            'revogado_em' => 'datetime',
        ];
    }

    public function casa(): BelongsTo
    {
        return $this->belongsTo(Casa::class);
    }
}
