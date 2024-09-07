import type { PluginListenerHandle } from '@capacitor/core';

export interface NativeAudio {
  configure(options: ConfigureOptions): Promise<void>;
  preload(options: PreloadOptions): Promise<void>;
  play(options: { assetId: string; time?: number }): Promise<void>;
  pause(options: { assetId: string }): Promise<void>;
  resume(options: { assetId: string }): Promise<void>;
  loop(options: { assetId: string }): Promise<void>;
  stop(options: { assetId: string }): Promise<void>;
  unload(options: { assetId: string }): Promise<void>;
  setVolume(options: { assetId: string; volume: number }): Promise<void>;
  getCurrentTime(options: { assetId: string }): Promise<{ currentTime: number }>;
  getDuration(options: { assetId: string }): Promise<{ duration: number }>;
  isPlaying(options: { assetId: string }): Promise<{ isPlaying: boolean }>;
  updateNowPlayingInfo(options: { assetId: string, title?: string, artist?: string }): Promise<void>;
  /*
   * Listen for asset playing state events
   */
  addListener(eventName: 'audioHasStartedPlaying', listenerFunc: (event: { assetId: string }) => void): Promise<PluginListenerHandle>;
  addListener(eventName: 'audioHasPausedPlaying', listenerFunc: (event: { assetId: string }) => void): Promise<PluginListenerHandle>;
  addListener(eventName: 'audioHasResumedPlaying', listenerFunc: (event: { assetId: string }) => void): Promise<PluginListenerHandle>;
  addListener(eventName: 'audioHasStoppedPlaying', listenerFunc: (event: { assetId: string }) => void): Promise<PluginListenerHandle>;
  /*
   * Listen for command center events
   */
  addListener(eventName: 'nextTrackCommandWasPressed', listenerFunc: (event: { assetId: string }) => void): Promise<PluginListenerHandle>;
  addListener(eventName: 'previousTrackCommandWasPressed', listenerFunc: (event: { assetId: string }) => void): Promise<PluginListenerHandle>;
  /**
   * Listen for asset completed playing event
   *
   * @since 5.0.1
   */
  addListener(eventName: 'complete', listenerFunc: (event: { assetId: string }) => void): Promise<PluginListenerHandle>;
}

export interface ConfigureOptions {
  /**
   * Indicating whether or not to fade audio.
   * @default false
   */
  fade?: boolean;
  /**
   * Indicating whether or not to disable mixed audio.
   * @default false
   */
  focus?: boolean;
}

export interface PreloadOptions {
  assetPath: string;
  assetId: string;
  volume?: number;
  audioChannelNum?: number;
  isUrl?: boolean;
}
