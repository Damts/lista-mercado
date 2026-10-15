<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Casa extends Model
{
    use HasFactory;

    protected $fillable = ['nome'];

    public function convites(): HasMany
    {
        return $this->hasMany(Convite::class);
    }

    public function pessoas(): BelongsToMany
    {
        return $this->belongsToMany(Pessoa::class, 'pessoa_casa');
    }
}
