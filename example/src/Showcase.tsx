import { useEffect, useRef, type ComponentRef } from 'react';
import {
  Image,
  Platform,
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  View,
} from 'react-native';
import { openEmojiPicker } from '@27appstudio/react-native-emoji-picker';
import { CHAT, sized } from './showcasePhotos';

// The README screenshots: a chat thread with the picker open on the reaction button
// of the first message, so the photo and the thread stay in view around it.
// It opens by itself once the screen is drawn. The tint (Splitify's default: ink, and
// cream in dark mode) fills the outgoing bubbles and is passed to the picker.
const TINT = { light: '#050F27', dark: '#FAF0D8' };

const PALETTE = {
  light: {
    background: '#FFFFFF',
    bar: '#F7F7F9',
    incoming: '#ECECF0',
    label: '#111114',
    onTint: '#FFFFFF',
    secondary: '#6E6E73',
    separator: '#E2E2E7',
  },
  dark: {
    background: '#000000',
    bar: '#121214',
    incoming: '#26262A',
    label: '#F5F5F7',
    onTint: '#050F27',
    secondary: '#98989F',
    separator: '#2C2C2E',
  },
};

export function Showcase() {
  const scheme = useColorScheme() === 'dark' ? 'dark' : 'light';
  const c = PALETTE[scheme];
  const tint = TINT[scheme];
  const anchor = useRef<ComponentRef<typeof View>>(null);

  useEffect(() => {
    const timer = setTimeout(() => {
      openEmojiPicker(anchor, { tintColor: tint });
    }, 1500);
    return () => clearTimeout(timer);
  }, [tint]);

  // Below the status bar: iOS's height on these iPhones, Android's own.
  const headerTop = {
    paddingTop:
      Platform.OS === 'ios' ? 62 : 12 + (StatusBar.currentHeight ?? 0),
  };
  const incoming = [styles.bubble, styles.in, { backgroundColor: c.incoming }];
  const outgoing = [styles.bubble, styles.out, { backgroundColor: tint }];

  return (
    <View style={[styles.screen, { backgroundColor: c.background }]}>
      <StatusBar
        barStyle={scheme === 'dark' ? 'light-content' : 'dark-content'}
      />
      <View
        style={[
          styles.header,
          {
            backgroundColor: c.bar,
            borderBottomColor: c.separator,
          },
          headerTop,
        ]}
      >
        <Text style={[styles.back, { color: tint }]}>‹</Text>
        <View style={styles.avatar}>
          <Text style={styles.initial}>M</Text>
        </View>
        <View>
          <Text style={[styles.name, { color: c.label }]}>Maya</Text>
          <Text style={[styles.status, { color: c.secondary }]}>online</Text>
        </View>
      </View>

      <View style={styles.thread}>
        <Text style={[styles.day, { color: c.secondary }]}>Today 18:04</Text>
        <View style={[styles.photoBubble, styles.in]}>
          <Image source={{ uri: sized(CHAT, 800, 600) }} style={styles.photo} />
        </View>
        <View style={styles.reactRow}>
          <View style={incoming}>
            <Text style={[styles.text, { color: c.label }]}>
              Landed! The water is unreal 🌊
            </Text>
          </View>
          <View
            ref={anchor}
            style={[styles.react, { backgroundColor: c.incoming }]}
          >
            <Text style={[styles.reactIcon, { color: c.secondary }]}>☺︎</Text>
          </View>
        </View>
        <View style={outgoing}>
          <Text style={[styles.text, { color: c.onTint }]}>
            No way. Save me a wave
          </Text>
        </View>
        <View style={incoming}>
          <Text style={[styles.text, { color: c.label }]}>
            Sunrise surf tomorrow, you in?
          </Text>
        </View>
        <View style={outgoing}>
          <Text style={[styles.text, { color: c.onTint }]}>
            In. 6 am at the beach
          </Text>
        </View>
      </View>

      <View
        style={[
          styles.composer,
          { backgroundColor: c.bar, borderTopColor: c.separator },
        ]}
      >
        <View style={[styles.field, { borderColor: c.separator }]}>
          <Text style={[styles.placeholder, { color: c.secondary }]}>
            Message
          </Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  avatar: {
    alignItems: 'center',
    backgroundColor: '#F4B183',
    borderRadius: 18,
    height: 36,
    justifyContent: 'center',
    width: 36,
  },
  back: { fontSize: 34, lineHeight: 36, marginRight: 4 },
  bubble: {
    borderRadius: 20,
    maxWidth: '78%',
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  composer: {
    borderTopWidth: StyleSheet.hairlineWidth,
    paddingBottom: 40,
    paddingHorizontal: 12,
    paddingTop: 8,
  },
  day: { alignSelf: 'center', fontSize: 12, marginBottom: 4 },
  field: {
    borderRadius: 20,
    borderWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  header: {
    alignItems: 'center',
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: 10,
    paddingBottom: 10,
    paddingHorizontal: 12,
  },
  in: { alignSelf: 'flex-start' },
  initial: { color: '#1C1B1F', fontSize: 16, fontWeight: '600' },
  name: { fontSize: 17, fontWeight: '600' },
  out: { alignSelf: 'flex-end' },
  photo: { height: 180, width: 240 },
  photoBubble: { borderRadius: 20, overflow: 'hidden' },
  placeholder: { fontSize: 17 },
  react: {
    alignItems: 'center',
    borderRadius: 16,
    height: 32,
    justifyContent: 'center',
    width: 32,
  },
  reactIcon: { fontSize: 18 },
  reactRow: { alignItems: 'center', flexDirection: 'row', gap: 8 },
  screen: { flex: 1 },
  status: { fontSize: 13 },
  text: { fontSize: 17 },
  thread: {
    flex: 1,
    gap: 8,
    paddingBottom: 12,
    paddingTop: 16,
    paddingHorizontal: 12,
  },
});
