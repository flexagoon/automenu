module GoogleDrive

using Downloads

export download

function download(folderid, output)
    folder = begin
        buf = IOBuffer()
        Downloads.download("https://drive.google.com/drive/folders/$folderid", buf)
        String(take!(buf))
    end

    fileid = match(r"file/d/([^/]+)/view", folder)[1]

    Downloads.download("https://docs.google.com/uc?export=download&id=$fileid", output)
end

end