#!/usr/bin/env bash
# Insert promoted beta/stable appcast items into the nightly appcast.
set -euo pipefail

FILTER_MODE="all"
if [ "${1:-}" = "--non-nightly-only" ]; then
  FILTER_MODE="non-nightly"
  shift
fi

PROMOTED="${1:?path to promoted appcast.xml}"
NIGHTLY="${2:?path to nightly appcast.xml}"

[ -f "$PROMOTED" ] || { echo "✗ Promoted appcast '$PROMOTED' not found" >&2; exit 1; }

if [ ! -f "$NIGHTLY" ]; then
  cat > "$NIGHTLY" <<'XML'
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>Contained</title>
    </channel>
</rss>
XML
fi

PROMOTED_APPCAST="$PROMOTED" FILTER_MODE="$FILTER_MODE" perl -0pi -e '
    my $source_path = $ENV{"PROMOTED_APPCAST"};
    my $filter_mode = $ENV{"FILTER_MODE"} // "all";
    open my $source_fh, "<", $source_path or die "Unable to read $source_path: $!";
    local $/;
    my $source = <$source_fh>;
    close $source_fh;

    my @promoted_items;
    while ($source =~ m{(<item>.*?</item>)}gs) {
        my $item = $1;
        $item =~ m{<sparkle:version>([^<]+)</sparkle:version>}
            or die "No sparkle:version in promoted item\n";
        my $version = $1;
        my ($short_version) = $item =~ m{<sparkle:shortVersionString>([^<]+)</sparkle:shortVersionString>};
        next if $filter_mode eq "non-nightly" && defined $short_version && $short_version =~ /-nightly\./;
        push @promoted_items, [$version, $item];
    }

    if (!@promoted_items) {
        next;
    }

    my $insert = "";
    for my $entry (@promoted_items) {
        my ($version, $item) = @$entry;
        my $quoted_version = quotemeta($version);
        s{\s*<item>.*?<sparkle:version>$quoted_version</sparkle:version>.*?</item>}{}gs;
        $insert .= "\n        $item\n";
    }

    s{(</title>\s*)}{$1$insert}s
        or die "No channel title found in nightly appcast\n";
' "$NIGHTLY"

echo "✓ Merged promoted appcast item(s) into $NIGHTLY"
