//----------------------------------------------------------------------------
// hoa_tests.dsp
// Tests for High Order Ambisonics helper functions.
//----------------------------------------------------------------------------

ho = library("hoa.lib");
os = library("oscillators.lib");

monoSignal(freq) = os.osc(freq);
stereoSignal(f1, f2) = monoSignal(f1), monoSignal(f2);

encoder_test = ho.encoder(1, monoSignal(440), 0.0);

rEncoder_test = monoSignal(440) : ho.rEncoder(1, 0.5, 0.0, 0.05);

stereoEncoder_test = stereoSignal(440, 660) : ho.stereoEncoder(1, 1.0);

multiEncoder_test = stereoSignal(440, 660) : ho.multiEncoder(1, (0.0, 0.0), (0.0, 1.57), 0.05);

encoder_bus = ho.encoder(1, monoSignal(440), 0.0);

decoder_test = encoder_bus : ho.decoder(1, 4);

decoderStereo_test = encoder_bus : ho.decoderStereo(1);

iBasicDecoder_test = encoder_bus : ho.iBasicDecoder(1, (0, 120, 240), 1, 0);

circularScaledVBAP_test = monoSignal(440) : ho.circularScaledVBAP((0, 120, 240), 60);

imlsDecoder_test = encoder_bus : ho.imlsDecoder(1, (0, 90, 180, 270), 1, 0);

iDecoder_test = (encoder_bus, 0.0) : ho.iDecoder(1, (0, 120, 240), 1, 0, 0.8);

optimBasic_test = encoder_bus : ho.optimBasic(1);

optimMaxRe_test = encoder_bus : ho.optimMaxRe(1);

optimInPhase_test = encoder_bus : ho.optimInPhase(1);

optim_test = encoder_bus : ho.optim(1, 1);

wider_test = encoder_bus : ho.wider(1, 0.5);

mirror_test = encoder_bus : ho.mirror(1, -1);

map_test = ho.map(1, monoSignal(440), 0.5, 0.0);

rotate_test = encoder_bus : ho.rotate(1, 0.78);

scope_test = encoder_bus : ho.scope(1, 0.1);

fxDecorrelation_test = encoder_bus : ho.fxDecorrelation(1, 64, 5, 0.5, 0.2, 0);

synDecorrelation_test = monoSignal(440) : ho.synDecorrelation(1, 64, 5, 0.5, 0.2, 0);

fxRingMod_test = encoder_bus : ho.fxRingMod(1, 200, 0.5, 0);

synRingMod_test = monoSignal(440) : ho.synRingMod(1, 200, 0.5, 0);

encoder3D_base = ho.encoder3D(1, monoSignal(440), 0.0, 0.0);

encoder3D_test = encoder3D_base;

rEncoder3D_test = monoSignal(440) : ho.rEncoder3D(1, 0.5, 0.3, 0.0, 0.0, 0.05);

optimBasic3D_test = encoder3D_base : ho.optimBasic3D(1);

optimMaxRe3D_test = encoder3D_base : ho.optimMaxRe3D(1);

optimInPhase3D_test = encoder3D_base : ho.optimInPhase3D(1);

optim3D_test = encoder3D_base : ho.optim3D(1, 2);
