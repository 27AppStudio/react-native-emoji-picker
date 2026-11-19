import { useRef, useState, type ComponentRef } from 'react';
import {
  Button,
  LogBox,
  Pressable,
  ScrollView,
  StatusBar,
  StyleSheet,
  Switch,
  Text,
  useColorScheme,
  View,
} from 'react-native';
import { openEmojiPicker } from '@27appstudio/react-native-emoji-picker';
import { Showcase } from './Showcase';

// Far from both platforms' defaults (system blue, Material's teal), so the switch shows.
const TINTS = { light: '#E8590C', dark: '#FFA94D' };
const LABELS = { light: '#1C1B1F', dark: '#E6E1E5' };
const BACKGROUNDS = { light: '#FFFFFF', dark: '#000000' };
const FIELDS = { light: '#F2F2F7', dark: '#1C1C1E' };

export default function App() {
  const scheme = useColorScheme() === 'dark' ? 'dark' : 'light';
  const [tinted, setTinted] = useState(true);
  const [french, setFrench] = useState(false);
  const [emoji, setEmoji] = useState('🍕');
  const [log, setLog] = useState('Tap the emoji');
  const topAnchor = useRef<ComponentRef<typeof View>>(null);
  const bottomAnchor = useRef<ComponentRef<typeof View>>(null);
  const [showcase, setShowcase] = useState(false);

  const open = async (anchor: typeof topAnchor) => {
    const picked = await openEmojiPicker(anchor, {
      tintColor: tinted ? TINTS[scheme] : undefined,
      locale: french ? 'fr' : undefined,
    });
    setLog(picked == null ? 'Dismissed' : `Picked ${picked}`);
    if (picked != null) {
      setEmoji(picked);
    }
  };

  if (showcase) {
    return <Showcase />;
  }

  return (
    <ScrollView
      // Android draws edge to edge: start below the status bar (iOS insets itself).
      contentContainerStyle={[
        styles.container,
        { paddingTop: 24 + (StatusBar.currentHeight ?? 0) },
      ]}
      contentInsetAdjustmentBehavior="automatic"
      style={{ backgroundColor: BACKGROUNDS[scheme] }}
    >
      <Text style={[styles.log, { color: LABELS[scheme] }]} testID="log">
        {log}
      </Text>
      <View style={styles.row}>
        <Text style={{ color: LABELS[scheme] }}>Tinted</Text>
        <Switch value={tinted} onValueChange={setTinted} testID="tinted" />
      </View>
      <View style={styles.row}>
        <Text style={{ color: LABELS[scheme] }}>French names (iOS)</Text>
        <Switch value={french} onValueChange={setFrench} testID="french" />
      </View>
      <Pressable
        ref={topAnchor}
        accessibilityRole="button"
        onPress={() => open(topAnchor)}
        style={[styles.field, { backgroundColor: FIELDS[scheme] }]}
        testID="open-top"
      >
        <Text style={styles.emoji}>{emoji}</Text>
      </Pressable>
      {/* The README screenshots, see scripts/screenshots. */}
      <Button
        title="Showcase: chat"
        testID="showcase-chat"
        onPress={() => {
          LogBox.ignoreAllLogs();
          setShowcase(true);
        }}
      />
      <View style={styles.spacer} />
      <Pressable
        ref={bottomAnchor}
        accessibilityRole="button"
        onPress={() => open(bottomAnchor)}
        style={[styles.field, { backgroundColor: FIELDS[scheme] }]}
        testID="open-bottom"
      >
        <Text style={styles.emoji}>{emoji}</Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    gap: 16,
    padding: 24,
  },
  log: {
    fontSize: 17,
  },
  row: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 12,
  },
  field: {
    alignItems: 'center',
    borderRadius: 12,
    height: 56,
    justifyContent: 'center',
    width: 56,
  },
  emoji: {
    fontSize: 30,
  },
  spacer: {
    height: 320,
  },
});
