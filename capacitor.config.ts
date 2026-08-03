import type { CapacitorConfig } from "@capacitor/cli";

/**
 * Configuração do wrapper nativo (caminho A).
 *
 * O app Android carrega a aplicação publicada diretamente do domínio de
 * produção, portanto SSR, rotas server-side e Supabase Realtime continuam
 * funcionando exatamente como na web — qualquer alteração feita no celular
 * aparece na web em tempo real e vice-versa.
 *
 * Consequência esperada: o app exige conexão com a internet (não há modo
 * offline). `webDir` existe apenas para satisfazer a CLI do Capacitor.
 */
const config: CapacitorConfig = {
  appId: "app.lovable.haulwatch",
  appName: "Kanban Operacional",
  webDir: "dist",
  server: {
    url: "https://haul-watch.lovable.app",
    // Nunca permitir tráfego HTTP em texto puro: o app só carrega via TLS.
    cleartext: false,
    androidScheme: "https",
  },
  android: {
    allowMixedContent: false,
  },
};

export default config;
