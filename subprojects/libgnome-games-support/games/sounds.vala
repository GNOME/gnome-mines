/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright © 2026 Will Warner
 *
 * This file is part of libgnome-games-support.
 *
 * libgnome-games-support is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * libgnome-games-support is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with libgnome-games-support.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Games {

public class Sounds : Object
{
    private ALC.Context context;
    private ALC.Device device;
    private HashTable<string, AL.Buffer> library =
        new HashTable<string, AL.Buffer> (str_hash, str_equal);

    private const int MAX_SOURCES = 32;
    private AL.Source[] sources;
    private uint source_index = 0;

    public Sounds (string sound_dir)
        throws Error
    {
        device = new ALC.Device (null);
        var device_error = device.get_error ();
        if (device_error != ALC.Error.NO_ERROR)
            error ("Got an ALC error while trying to open device: code %d", device_error);

        context = new ALC.Context (device, null);
        var context_error = device.get_error ();
        if (context_error != ALC.Error.NO_ERROR)
            error ("Got an ALC error while trying to create context: code %d", context_error);

        context.make_current ();

        var directory = File.new_for_path (sound_dir);
        if (!directory.query_exists ())
            throw new FileError.NOENT ("Sound directory does not exist");

        var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);
        FileInfo file_info;
        while ((file_info = enumerator.next_file ()) != null)
        {
            var filename = file_info.get_name ();
            var path = Path.build_filename (sound_dir, filename);

            var info = Sndfile.Info ();
            var file = new Sndfile.File (path, Sndfile.Mode.READ, ref info);

            if (file == null) {
                critical ("Could not open audio file: %s", filename);
                continue;
            }

            AL.BufferFormat format;
            switch (info.channels) {
                case 1:
                    format = AL.BufferFormat.MONO16;
                    break;
                case 2:
                    format = AL.BufferFormat.STEREO16;
                    break;
                default:
                    warning ("Unable to load sound: More than two channels are not supported");
                    continue;
            }

            var sample_count = info.frames * info.channels;
            var data = new AL.Short[sample_count];
            if (file.readf_short (data, info.frames) < info.frames)
            {
                warning ("Unable to load sound: file ended unexpectedly");
                continue;
            }

            AL.Buffer buffer;
            AL.gen_buffer (1, out buffer);
            buffer.set_data (format, data, sample_count * 2, info.samplerate); // Short is 16-bit -> 2 bytes
            var sound_error = AL.get_error ();

            if (sound_error == AL.Error.NO_ERROR)
                library.insert (filename, buffer);
            else
                warning ("Got an AL error while loading sound: code %d", sound_error);
        }

        sources = new AL.Source[MAX_SOURCES];
        AL.gen_sources (MAX_SOURCES, sources);
        foreach (unowned var source in sources)
        {
            source.set_paramf (AL.PITCH, 1.0f);
            source.set_paramf (AL.GAIN, 1.0f);
        }

        AL.distance_model (AL.NONE); // Don't use 3d sound
    }

    /**
     * Plays a sound by filename
     */
    public void play (string filename)
    {
        unowned AL.Buffer? buffer = library[filename];
        if (buffer == null)
        {
            warning ("Sound not found: %s", filename);
            return;
        }

        AL.get_error (); // Clear errors
        source_index = (source_index + 1) % MAX_SOURCES;
        var source = sources[source_index];
        source.stop ();
        source.rewind ();
        source.set_parami (AL.BUFFER, (AL.Int) buffer);
        source.play ();
        var error = AL.get_error ();
        if (error != AL.Error.NO_ERROR)
            warning ("Got an AL error while trying to play sound: code %d", error);
    }

    public override void dispose ()
    {
        AL.delete_sources (MAX_SOURCES, sources);
        foreach (var buffer in library.get_values_as_ptr_array ())
            AL.delete_buffer (1, ref buffer);

        base.dispose ();
    }
}

} /* namespace Games */
