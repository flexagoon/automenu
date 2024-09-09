module Notifier

using Telegram, Telegram.API
using ..Config

export notify

function notify(message::AbstractString, config::Config.Notifier)
    tg = TelegramClient(config.bot_token; chat_id=config.chat_id)
    sendMessage(tg; text=message)
end

end
