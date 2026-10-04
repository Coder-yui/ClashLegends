import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'audio'))
from original_gain import validate_txtp, render_fresh


class OriginalGainTests(unittest.TestCase):
    def test_reject_auto_before_overwriting_cache(self):
        with tempfile.TemporaryDirectory() as d:
            source = Path(d)/'event.txtp'
            target = Path(d)/'preview.wav'
            source.write_text('media.wem\n# * master volume: auto (20.0dB)\n')
            target.write_bytes(b'old preview')
            with self.assertRaises(ValueError):
                render_fresh(source, target)
            self.assertEqual(target.read_bytes(), b'old preview')

    def test_preserve_event_attenuation_and_invalidate_old_preview(self):
        with tempfile.TemporaryDirectory() as d:
            source = Path(d)/'event.txtp'
            target = Path(d)/'preview.wav'
            source.write_text('media.wem #v -20.0dB\n# * master volume: 0dB\n')
            validate_txtp(source)
            target.write_bytes(b'stale auto preview')
            def decode(command, **kwargs):
                Path(command[command.index('-o')+1]).write_bytes(b'RIFF'+b'new PCM'*10)
            with patch('original_gain.subprocess.run', side_effect=decode) as run:
                render_fresh(source, target)
                render_fresh(source, target)
            self.assertEqual(run.call_count, 2)
            self.assertTrue(target.read_bytes().startswith(b'RIFF'))

    def test_reject_fixed_tool_master_gain(self):
        with tempfile.TemporaryDirectory() as d:
            source = Path(d)/'event.txtp'
            source.write_text('# * master volume: 3.0dB\n')
            with self.assertRaises(ValueError):
                validate_txtp(source)
