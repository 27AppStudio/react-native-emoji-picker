import { TurboModuleRegistry, type TurboModule } from 'react-native';

type Rect = {
  x: number;
  y: number;
  width: number;
  height: number;
};

type OpenOptions = {
  /** iOS: what the popover points at, in window coordinates. */
  anchor: Rect;
  /** A `processColor` value; missing keeps the platform default. */
  tintColor?: number;
  /** `unspecified`, `light` or `dark`. */
  userInterfaceStyle: string;
  /** iOS: the language of the search keywords and section titles (`fr`, `pt-BR`…). */
  locale?: string;
};

export interface Spec extends TurboModule {
  /** Shows the picker and resolves with the emoji picked, or null when it was dismissed. */
  open(options: OpenOptions): Promise<string | null>;
}

// Missing on web and in Expo Go: see `isAvailable`.
export default TurboModuleRegistry.get<Spec>('RNEmojiPicker');
