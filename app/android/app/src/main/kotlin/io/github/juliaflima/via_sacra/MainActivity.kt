package io.github.juliaflima.via_sacra

import com.ryanheise.audioservice.AudioServiceActivity

/**
 * Atividade principal. Estende AudioServiceActivity para que a leitura da
 * Liturgia continue em segundo plano e apareça na tela de bloqueio.
 */
class MainActivity : AudioServiceActivity()
