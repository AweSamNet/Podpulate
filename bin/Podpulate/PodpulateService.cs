using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Linq;

namespace AweSamNet.Podpulate
{
    public class PodpulateService
    {
        private readonly XDocument _xdoc;
        private const string TemplatePath = "../Podpulate/xml/iTunesTemplate.xml";

        private DateTime _highestDate = DateTime.MinValue;

        public PodpulateService(string xmlPath = null)
        {

            if (string.IsNullOrWhiteSpace(xmlPath))
            {
                _xdoc = XDocument.Load(TemplatePath);
                var channel = _xdoc.Descendants("channel").FirstOrDefault();

                var defaultItem = channel.Descendants("item")
                    .FirstOrDefault();

                if (defaultItem != null) defaultItem.Remove();
            }
            else
            {
                _xdoc = XDocument.Load(xmlPath);
            }
        }

        public static PodpulateService Create(string xmlPath = null)
        {
            return new PodpulateService(xmlPath);
        }

        public bool HasFile(string filePartialUrl)
        {
            return
                _xdoc.Descendants("channel")
                    .Any(
                        channel => channel.Descendants("item")
                            .Any(item =>
                                item.Element("link").Value.Contains(filePartialUrl)));
        }

        public bool IsNewer(DateTime timestamp)
        {
            var channel = _xdoc.Descendants("channel").FirstOrDefault();
            if (channel == null) return false;
            var items = channel.Descendants("item");
            if (!items.Any()) return true;

            //get the highest date time
            if (_highestDate == DateTime.MinValue)
            {
                _highestDate = items.Max(x => pubDate(x));
            }

            return timestamp > _highestDate;
        }



        public void AddItem(string podcastUrl, DateTime timeStamp, long size, bool onlyNewer = false)
        {
            //first load what an item template
            var path = System.IO.Path.GetDirectoryName(
                System.Reflection.Assembly.GetExecutingAssembly().GetName().CodeBase);

            var xdocTemplate = XDocument.Load(TemplatePath);

            var item = xdocTemplate.Descendants("channel")
                .Select(channel =>
                    channel.Descendants("item")
                        .FirstOrDefault())
                .FirstOrDefault();

            if (item != null)
            {
                var channel = _xdoc.Descendants("channel").FirstOrDefault();

                if (channel != null)
                {
                    XNamespace ns = "itunes";
                    //try to get the author
                    var author = channel.Elements().FirstOrDefault(x => x.Name.LocalName == "author");
                    if (author != null)
                    {
                        item.Elements().First(x => x.Name.LocalName == "author").Value = author.Value;
                    }

                    item.SetElementValue("link", podcastUrl);
                    item.SetElementValue("guid", podcastUrl);
                    var timeZone = string.Format("{0:zzz}", timeStamp).Replace(":", String.Empty);
                    item.SetElementValue("pubDate",
                        string.Format("{0:ddd, dd MMM yyyy hh:mm:ss} {1}", timeStamp, timeZone));
                    var enclosure = item.Element("enclosure");
                    if (enclosure != null)
                    {
                        enclosure.SetAttributeValue("url", podcastUrl);
                        enclosure.SetAttributeValue("length", size);
                    }

                    AddItem(item);
                    return;
                    //return _xdoc.ToString();
                }
            }

            throw new Exception("Template \"../Podpulate/xml/iTunesTemplate.xml\" was not found or was corrupt.");
        }

        private void AddItem(XElement item, bool replace = false, bool onlyNewer = false)
        {
            var channel = _xdoc.Descendants("channel").FirstOrDefault();
            //find element to put this above
            var items = channel
                .Descendants("item")
                .ToList();

            if (replace)
            {
                //see if we have the item
                var existingItem = items.FirstOrDefault(x => link(x) == link(item));
                if (existingItem != null)
                {
                    existingItem.ReplaceWith(item);
                    return;
                }
            }

            if (items.Any())
            {
                if (onlyNewer && items.All(x => pubDate(x) > pubDate(item)))
                {
                    return;
                }

                var previousElement = items
                    .Where(x =>
                    {
                        var parsed = pubDate(x);
                        return parsed != DateTime.MinValue && parsed < pubDate(item);
                    })
                    .OrderByDescending(x => pubDate(x))
                    .FirstOrDefault();

                if (previousElement != null)
                {
                    previousElement.AddBeforeSelf(item);
                }
                else
                {
                    items.Last().AddAfterSelf(item);
                }
            }
            else
            {
                _xdoc.Descendants("channel").First().Add(item);
            }
        }

        public override string ToString()
        {
            return _xdoc.ToString();
        }

        public void Save(string filePath)
        {
            _xdoc.Save(filePath);
        }

        public void LoadHeadersFromXml(string filePath)
        {
            XDocument toCopy = XDocument.Load(filePath);
            var channel = _xdoc.Descendants("channel").FirstOrDefault();
            var channelToCopy = toCopy.Descendants("channel").FirstOrDefault();

            if (channel != null && channelToCopy != null)
            {
                var title = channelToCopy.Elements("title").FirstOrDefault();
                if (title != null)
                {
                    var e = channel.Elements("title").FirstOrDefault();
                    if (e != null)
                    {
                        e.ReplaceWith(title);
                    }
                    else
                    {
                        channel.AddFirst(title);
                    }
                }

                var link = channelToCopy.Elements("link").FirstOrDefault();
                if (link != null)
                {
                    var e = channel.Elements("link").FirstOrDefault();
                    if (e != null)
                    {
                        e.ReplaceWith(link);
                    }
                    else
                    {
                        channel.AddFirst(link);
                    }
                }

                var description = channelToCopy.Elements("description").FirstOrDefault();
                if (description != null)
                {
                    var e = channel.Elements("description").FirstOrDefault();
                    if (e != null)
                    {
                        e.ReplaceWith(description);
                    }
                    else
                    {
                        channel.AddFirst(description);
                    }
                }

                var language = channelToCopy.Elements("language").FirstOrDefault();
                if (title != null)
                {
                    var e = channel.Elements("language").FirstOrDefault();
                    if (e != null)
                    {
                        e.ReplaceWith(language);
                    }
                    else
                    {
                        channel.AddFirst(language);
                    }
                }

                var copyright = channelToCopy.Elements("copyright").FirstOrDefault();
                if (title != null)
                {
                    var e = channel.Elements("copyright").FirstOrDefault();
                    if (e != null)
                    {
                        e.ReplaceWith(copyright);
                    }
                    else
                    {
                        channel.AddFirst(copyright);
                    }
                }

                var image = channelToCopy.Elements("image").FirstOrDefault();
                if (title != null)
                {
                    var e = channel.Elements("image").FirstOrDefault();
                    if (e != null)
                    {
                        e.ReplaceWith(image);
                    }
                    else
                    {
                        channel.AddFirst(image);
                    }
                }

                var summary = channelToCopy.Elements().FirstOrDefault(x => x.Name.LocalName == "summary");
                if (title != null)
                {
                    var e = channel.Elements().FirstOrDefault(x => x.Name.LocalName == "summary");
                    if (e != null)
                    {
                        e.ReplaceWith(summary);
                    }
                    else
                    {
                        channel.AddFirst(summary);
                    }
                }

                var subtitle = channelToCopy.Elements().FirstOrDefault(x => x.Name.LocalName == "subtitle");
                if (title != null)
                {
                    var e = channel.Elements().FirstOrDefault(x => x.Name.LocalName == "subtitle");
                    if (e != null)
                    {
                        e.ReplaceWith(subtitle);
                    }
                    else
                    {
                        channel.AddFirst(subtitle);
                    }
                }

                var author = channelToCopy.Elements().FirstOrDefault(x => x.Name.LocalName == "author");
                if (title != null)
                {
                    var e = channel.Elements().FirstOrDefault(x => x.Name.LocalName == "author");
                    if (e != null)
                    {
                        e.ReplaceWith(author);
                    }
                    else
                    {
                        channel.AddFirst(author);
                    }
                }

                var owner = channelToCopy.Elements().FirstOrDefault(x => x.Name.LocalName == "owner");
                if (title != null)
                {
                    var e = channel.Elements().FirstOrDefault(x => x.Name.LocalName == "owner");
                    if (e != null)
                    {
                        e.ReplaceWith(owner);
                    }
                    else
                    {
                        channel.AddFirst(owner);
                    }
                }

                var @explicit = channelToCopy.Elements().FirstOrDefault(x => x.Name.LocalName == "explicit");
                if (title != null)
                {
                    var e = channel.Elements().FirstOrDefault(x => x.Name.LocalName == "explicit");
                    if (e != null)
                    {
                        e.ReplaceWith(@explicit);
                    }
                    else
                    {
                        channel.AddFirst(@explicit);
                    }
                }

                var category = channelToCopy.Elements().FirstOrDefault(x => x.Name.LocalName == "category");
                if (title != null)
                {
                    var e = channel.Elements().FirstOrDefault(x => x.Name.LocalName == "category");
                    if (e != null)
                    {
                        e.ReplaceWith(category);
                    }
                    else
                    {
                        channel.AddFirst(category);
                    }
                }
            }
        }

        public void LoadItemsFromXml(string filePath)
        {
            XDocument toCopy = XDocument.Load(filePath);
            var channel = _xdoc.Descendants("channel").FirstOrDefault();
            var channelToCopy = toCopy.Descendants("channel").FirstOrDefault();

            if (channel != null && channelToCopy != null)
            {
                var itemsToCopy = channelToCopy.Descendants("item");
                //get the filename as the identifier
                foreach (var item in itemsToCopy)
                {
                    AddItem(item, true);
                }
            }
        }

        private static Func<XElement, DateTime> pubDate = (x) =>
        {
            DateTime parsed;
            DateTime.TryParseExact(x.Element("pubDate").Value.Substring(0, x.Element("pubDate").Value.Length - 6),
                "ddd, dd MMM yyyy HH:mm:ss",
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out parsed);
            return parsed;
        };

        private static Func<XElement, string> link = (x) =>
        {
            var link = x.Elements("link").FirstOrDefault();
            return link != null ? link.Value : null;
        };
    }
}
