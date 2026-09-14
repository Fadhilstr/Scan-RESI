#!/usr/bin/env perl
use strict;
use warnings;
use lib '/app/lib';
use Wahana::Db;
use Wahana::Query;
use Wahana::Controller::PaketController;

my $dbh = Wahana::Db->connect();

my $andre_id = 'USR-CUST-002';
my $wahyu_id = 'USR-004';

print "Menghapus data paket...\n";
$dbh->do("DELETE FROM paket WHERE created_by IN (?, ?)", undef, $andre_id, $wahyu_id);

print "Menghapus scan_events wahyu...\n";
$dbh->do("DELETE FROM scan_events WHERE user_id = ?", undef, $wahyu_id);

print "Reset task wahyu...\n";
$dbh->do("UPDATE tasks SET progress = 0, status = 'PROSES_SCAN' WHERE user_id = ?", undef, $wahyu_id);

my @formats = qw(CODE_128 QR_CODE AZTEC DATA_MATRIX PDF_417 CODE_39 CODE_93 CODABAR ITF EAN_13 EAN_8 UPC_A UPC_E RSS_14 RSS_EXPANDED);

print "Membuat paket test untuk Andre...\n";
my $draft_base = time();
for my $i (0 .. $#formats) {
    my $fmt = $formats[$i];
    my $draft_id = sprintf("DRF-TEST-%04X", $draft_base + $i);
    
    my $resi;
    eval {
        $resi = Wahana::Controller::PaketController::generate_resi($dbh, $fmt);
    };
    if ($@) {
        warn "Gagal generate resi untuk format $fmt: $@\n";
        next;
    }
    
    my $barcode_val = Wahana::Controller::PaketController::generate_barcode_value($resi, $fmt);
    
    my $nama = "Test Packet $fmt";
    my $pengirim = "Andre Test";
    my $alamat = "Alamat Test";
    my $telp = "081234567890";
    
    $dbh->do(
        Wahana::Query->get('paket_insert_draft'),
        undef, $resi, $andre_id, $draft_id, $fmt, $barcode_val,
        $nama, $pengirim, $alamat, $telp,
        "Penerima $fmt", $alamat, $telp,
        1.5, 'REGULER'
    );
    
    $dbh->do("UPDATE paket SET status = 'TERDAFTAR' WHERE nomor_resi = ?", undef, $resi);
    print "  -> Created $fmt (Resi: $resi, BV: $barcode_val)\n";
}

print "Selesai.\n";
